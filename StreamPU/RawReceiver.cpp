#include "RawReceiver.hpp"
#include <iostream>
#include <cstring>
#include <cstdio>
#include <sys/ioctl.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <chrono> // Ajout pour le chronomètre global

RawReceiver::RawReceiver(const std::string& interface, size_t max_payload_size) : spu::module::Stateful()
{
    this->set_name("RawReceiver");
    
    // --- 1. CRÉATION DU SOCKET RAW ---
    // Exactement comme l'émetteur, on ouvre un canal direct avec la carte réseau (Niveau 2).
    // ETH_P_ALL : Demande au noyau de nous faire suivre TOUS les protocoles (IPv4, ARP, etc.),
    // sans exception, au lieu de ne filtrer que l'IP par exemple.
    sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) throw std::runtime_error("Erreur socket réception (sudo requis)");

    // --- 2. CONFIGURATION DU TIMEOUT (DÉLAI D'ATTENTE) ---
    // Si on ne met pas ça, la fonction recvfrom() bloquera le programme à l'infini
    // tant qu'aucun paquet ne traverse la carte réseau. 
    // SO_RCVTIMEO = "Socket Option Receive Timeout".
    struct timeval tv;
    tv.tv_sec = 20; // 20 secondes d'attente maximum par appel de recvfrom()
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));

    // --- 3. RÉCUPÉRATION DE L'INDEX DE LA CARTE RÉSEAU ---
    std::memset(&ifr, 0, sizeof(ifr));
    std::strncpy(ifr.ifr_name, interface.c_str(), IFNAMSIZ - 1);
    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
        close(sock);
        throw std::runtime_error("Interface réception introuvable");
    }

    // --- 4. ATTACHEMENT (BIND) DU SOCKET À L'INTERFACE ---
    // Contrairement à l'émetteur qui précise l'interface à chaque "sendto",
    // le récepteur "s'accroche" (bind) à la carte réseau une bonne fois pour toutes.
    // S'il ne le faisait pas, il écouterait TOUTES les cartes réseau du PC (Wi-Fi, Ethernet, boucle locale...).
    std::memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;
    sll.sll_ifindex = ifr.ifr_ifindex; // "Je n'écoute QUE sur cet index précis"
    sll.sll_protocol = htons(ETH_P_ALL);
    if (bind(sock, (struct sockaddr*)&sll, sizeof(sll)) < 0) {
        close(sock);
        throw std::runtime_error("Erreur de bind sur l'interface");
    }

    auto& t = this->create_task("receive");
    this->create_socket_in<uint8_t>(t, "trigger", 1);
    this->create_socket_out<uint8_t>(t, "payload", max_payload_size);
    this->create_socket_out<uint32_t>(t, "length", 1);

    this->create_codelet(t, [this](spu::module::Module&, spu::runtime::Task& t, const size_t)
    {
        auto* trigger      = static_cast<const uint8_t*>(t[0].get_dataptr());
        auto* payload_out  = static_cast<uint8_t*>(t[1].get_dataptr());
        auto* length_out   = static_cast<uint32_t*>(t[2].get_dataptr());

        if (trigger[0] == 0) {
            length_out[0] = 0;
            return spu::runtime::status_t::FAILURE;
        }

        unsigned char buffer[2048]; // Le tampon où le noyau va copier la trame reçue
        bool packet_found = false;

        std::cout << "\n[RawReceiver] === Écoute réseau en cours (Max 20s) ===" << std::endl;

        // sockaddr_ll va servir à récupérer les "métadonnées" du paquet
        // (Ex: Est-ce un paquet entrant, sortant, diffusé à tout le monde ?)
        struct sockaddr_ll src_addr;
        socklen_t addr_len = sizeof(src_addr);

        auto start_time = std::chrono::steady_clock::now();

        while (!packet_found) {
            
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
            
            if (elapsed >= 20) {
                std::cerr << "[RawReceiver] Timeout global (20s) : Temps écoulé, abandon." << std::endl;
                length_out[0] = 0;
                return spu::runtime::status_t::FAILURE;
            }

            // --- 5. LECTURE DE LA TRAME ---
            // recvfrom() va chercher le prochain paquet disponible dans le buffer de la carte réseau.
            // Si le buffer est vide, il s'endort et attend (jusqu'à la limite de notre timeout).
            ssize_t data_size = recvfrom(this->sock, buffer, sizeof(buffer), 0, 
                                        (struct sockaddr*)&src_addr, &addr_len);
            
            if (data_size < 0) {
                std::cerr << "[RawReceiver] Silence réseau (20s) : Aucun paquet cible détecté." << std::endl;
                length_out[0] = 0;
                return spu::runtime::status_t::FAILURE;
            }

            // --- 6. PREMIER FILTRE : DIRECTION DU TRAFIC ---
            // sll_pkttype indique la direction. PACKET_OUTGOING = émis par NOTRE machine.
            // Le noyau Linux renvoie par défaut un écho de ce qu'on envoie. On l'ignore.
            if (src_addr.sll_pkttype == PACKET_OUTGOING) continue;

            // --- 7. DEUXIÈME FILTRE : ANALYSE DE L'EN-TÊTE ETHERNET ---
            // Une trame Ethernet valide possède au strict minimum 14 octets (6 MAC Dest + 6 MAC Src + 2 Type).
            if (data_size >= 14) {
                char mac_dest[18], mac_src[18];
                snprintf(mac_dest, sizeof(mac_dest), "%02X:%02X:%02X:%02X:%02X:%02X", 
                         buffer[0], buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
                snprintf(mac_src, sizeof(mac_src), "%02X:%02X:%02X:%02X:%02X:%02X", 
                         buffer[6], buffer[7], buffer[8], buffer[9], buffer[10], buffer[11]);

                uint16_t eth_type = (buffer[12] << 8) | buffer[13];
                std::string nom_protocole;
                switch(eth_type) {
                    case 0x0800: nom_protocole = "IPv4"; break;
                    case 0x0806: nom_protocole = "ARP"; break;
                    case 0x86DD: nom_protocole = "IPv6"; break;
                    case 0x88B5: nom_protocole = "Expérimental"; break;
                    default:     nom_protocole = "Autre"; break;
                }

                std::cout << "[RawReceiver] Trame | Src: " << mac_src << " -> Dest: " << mac_dest 
                          << " | Type: " << nom_protocole << " | Taille: " << data_size << "o" << std::endl;

                // --- 8. FILTRAGE FINAL SUR LA CIBLE ---
                // On vérifie bit par bit si la trame était adressée à notre MAC fictive (00:11:22:33:44:55).
                if (buffer[0] == 0x00 && buffer[1] == 0x11 && buffer[2] == 0x22 &&
                    buffer[3] == 0x33 && buffer[4] == 0x44 && buffer[5] == 0x55) 
                {
                    // On retire les 14 octets d'en-tête pour ne récupérer que le payload pur
                    uint32_t payload_len = data_size - 14;
                    std::memcpy(payload_out, buffer + 14, payload_len);
                    length_out[0] = payload_len;
                    std::cout << "  => CIBLE TROUVÉE !\n" << std::endl;
                    packet_found = true;
                }
            }
        }
        return spu::runtime::status_t::SUCCESS;
    });
}

// Le destructeur libère la ressource système (le file descriptor du socket)
RawReceiver::~RawReceiver() { if (sock >= 0) close(sock); }