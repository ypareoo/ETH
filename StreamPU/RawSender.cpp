#include "RawSender.hpp"
#include <iostream>
#include <cstring>
#include <sys/ioctl.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <unistd.h>

RawSender::RawSender(const std::string& interface, size_t max_payload_size) : spu::module::Stateful()
{
    this->set_name("RawSender");
    std::cout << "[RawSender] Initialisation sur " << interface << std::endl;
    
    // --- 1. CRÉATION DU SOCKET RAW ---
    // AF_PACKET : Permet de travailler directement sur la couche liaison de données (Niveau 2 - adresses MAC).
    // SOCK_RAW : Indique qu'on va construire nous-mêmes l'en-tête du paquet (Ethernet II complet).
    // htons(ETH_P_ALL) : Permet d'envoyer (et recevoir) n'importe quel protocole réseau. htons gère le "boutisme" (endianness).
    sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) throw std::runtime_error("Erreur socket (sudo requis)");

    // --- 2. RÉCUPÉRATION DE L'INDEX DE L'INTERFACE RÉSEAU ---
    // L'OS a besoin d'un numéro d'index, pas d'un nom de texte brut comme "enp3s0" pour envoyer la trame.
    std::memset(&ifr, 0, sizeof(ifr)); // On initialise la structure de requête à 0
    std::strncpy(ifr.ifr_name, interface.c_str(), IFNAMSIZ - 1); // On y copie le nom de l'interface cible
    
    // ioctl (Input/Output Control) interroge le noyau Linux. 
    // SIOCGIFINDEX = "Socket I/O Control Get InterFace INDEX".
    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
        close(sock);
        throw std::runtime_error("Interface introuvable");
    }

    // --- 3. PRÉPARATION DE L'ADRESSE DE DESTINATION PHYSIQUE ---
    // sockaddr_ll (Link Layer) est la structure utilisée pour le routage de bas niveau.
    std::memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;      // Famille d'adresses pour la couche physique
    sll.sll_ifindex = ifr.ifr_ifindex; // On précise qu'on veut sortir par l'interface trouvée précédemment
    sll.sll_halen = ETH_ALEN;        // Longueur de l'adresse matérielle (MAC = 6 octets)

    auto& t = this->create_task("send");
    this->create_socket_in<uint8_t>(t, "payload", max_payload_size);
    this->create_socket_in<uint32_t>(t, "length", 1);
    this->create_socket_out<uint8_t>(t, "send_status", 1);

    this->create_codelet(t, [this](spu::module::Module&, spu::runtime::Task& t, const size_t)
    {
        auto* payload_ptr = static_cast<const uint8_t*>(t[0].get_dataptr());
        uint32_t payload_len = *static_cast<const uint32_t*>(t[1].get_dataptr());
        auto* status_ptr  = static_cast<uint8_t*>(t[2].get_dataptr());

        // --- 4. CONSTRUCTION MANUELLE DE LA TRAME ETHERNET ---
        unsigned char frame[1514]; // 1514 octets = Taille max classique (14 octets d'en-tête + 1500 de payload)
        
        // Définition de l'en-tête Ethernet (14 octets au total)
        unsigned char mac_dest[] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55}; // 6 octets : Adresse MAC du destinataire
        unsigned char mac_src[]  = {0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB}; // 6 octets : Adresse MAC de l'émetteur (nous)
        unsigned char eth_type[] = {0x88, 0xB5};                         // 2 octets : Protocole (0x88B5 = Expérimental/Local)

        // Assemblage dans le buffer `frame`
        std::memcpy(frame, mac_dest, 6);              // Écriture de la MAC Destination (Octets 0 à 5)
        std::memcpy(frame + 6, mac_src, 6);           // Écriture de la MAC Source (Octets 6 à 11)
        std::memcpy(frame + 12, eth_type, 2);         // Écriture de l'EtherType (Octets 12 et 13)
        std::memcpy(frame + 14, payload_ptr, payload_len); // Ajout de la charge utile (Octets 14 à la fin)

        // On précise la MAC de destination à l'interface socket pour le ciblage final sur le réseau
        std::memcpy(sll.sll_addr, mac_dest, 6);

        // --- 5. ENVOI PHYSIQUE DE LA TRAME ---
        size_t total_len = 14 + payload_len; // Taille de l'en-tête + Taille du message
        
        // sendto envoie les données brutes sur le câble.
        // - this->sock : le descripteur du socket réseau
        // - frame : le pointeur vers notre tableau d'octets assemblés
        // - total_len : le nombre d'octets à injecter
        // - (struct sockaddr*)&this->sll : la structure qui indique au noyau par quelle carte réseau sortir
        ssize_t sent = sendto(this->sock, frame, total_len, 0, 
                             (struct sockaddr*)&this->sll, sizeof(this->sll));

        if (sent > 0) {
            std::cout << "[RawSender] Succès : " << sent << " octets envoyés." << std::endl;
            status_ptr[0] = 1; 
        } else {
            perror("[RawSender] Erreur sendto");
            status_ptr[0] = 0; 
        }
        return spu::runtime::status_t::SUCCESS;
    });
}

// --- 6. FERMETURE DU SOCKET ---
// Le destructeur garantit que le socket réseau est fermé et rendu au système d'exploitation à la fin du programme.
RawSender::~RawSender() { if (sock >= 0) close(sock); }