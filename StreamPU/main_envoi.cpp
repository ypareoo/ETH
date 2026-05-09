#include <streampu.hpp>
#include <iostream>
#include <vector>
#include <cstring>

// Headers Linux pour les sockets Raw
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netpacket/packet.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <fstream>
#include <filesystem>

// ==========================
// MODULE 1 : Générateur de Payload
// ==========================
class FrameGenerator : public spu::module::Stateful
{
public:
    FrameGenerator(size_t max_size) : spu::module::Stateful()
    {
        this->set_name("FrameGenerator");
        auto& t = this->create_task("generate");
        this->create_socket_out<uint8_t>(t, "payload", max_size);
        this->create_socket_out<uint32_t>(t, "length", 1);

        this->create_codelet(t, [](spu::module::Module&, spu::runtime::Task& t, const size_t)
        {
            auto* payload_ptr = static_cast<uint8_t*>(t[0].get_dataptr());
            auto* length_ptr  = static_cast<uint32_t*>(t[1].get_dataptr());

            // Payload fixe (les données qui seront après l'EtherType)
            
            //std::cout << std::filesystem::current_path() << std::endl;
            
            std::ifstream fich {"src/payload.txt"};
            //std::string s;
            std::string s;
            if(fich) {
                fich >> s;
                
            } 
            else {
                std::cout << "ERREUR dans la lecture de payload.txt"<< std::endl;
                s = "\xAA\xAA\xAA\xAA\xAA\xAA";
            }
            
            //const char* data = "\xDE\xAD\xBE\xEF\xCA\xFE";
            const char* data = s.c_str();
            uint32_t len = s.size();

            std::memcpy(payload_ptr, data, len);
            length_ptr[0] = len;

            std::cout << "[FrameGenerator] Payload prêt" << std::endl;
            return spu::runtime::status_t::SUCCESS;
        });
    }
};

// ==========================
// MODULE 2 : Émetteur Raw Ethernet
// ==========================
class RawSender : public spu::module::Stateful
{
private:
    int sock;
    struct ifreq ifr;
    struct sockaddr_ll sll;

public:
    RawSender(const std::string& interface, size_t max_payload_size) : spu::module::Stateful()
    {
        this->set_name("RawSender");
        std::cout << "[RawSender] Initialisation sur " << interface << std::endl;
        
        // 1. Ouverture du socket Raw
        sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
        if (sock < 0) throw std::runtime_error("Erreur socket (sudo requis)");

        // 2. Récupération de l'index de l'interface
        std::memset(&ifr, 0, sizeof(ifr));
        std::strncpy(ifr.ifr_name, interface.c_str(), IFNAMSIZ - 1);
        if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
            close(sock);
            throw std::runtime_error("Interface introuvable");
        }

        // 3. Configuration de l'adresse de destination
        std::memset(&sll, 0, sizeof(sll));
        sll.sll_family = AF_PACKET;
        sll.sll_ifindex = ifr.ifr_ifindex;
        sll.sll_halen = ETH_ALEN;

        // Création de la tâche
        auto& t = this->create_task("send");
        this->create_socket_in<uint8_t>(t, "payload", max_payload_size);
        this->create_socket_in<uint32_t>(t, "length", 1);
        
        // CORRECTION ICI : "send_status" au lieu de "status" (mot réservé)
        this->create_socket_out<uint8_t>(t, "send_status", 1);

        this->create_codelet(t, [this](spu::module::Module&, spu::runtime::Task& t, const size_t)
        {
            auto* payload_ptr = static_cast<const uint8_t*>(t[0].get_dataptr());
            uint32_t payload_len = *static_cast<const uint32_t*>(t[1].get_dataptr());
            auto* status_ptr  = static_cast<uint8_t*>(t[2].get_dataptr());

            // Construction de la trame Ethernet complète
            unsigned char frame[1514];
            
            // MAC Destination: 00:11:22:33:44:55
            unsigned char mac_dest[] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
            // MAC Source: 66:77:88:99:AA:BB
            unsigned char mac_src[]  = {0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB};
            // EtherType: 0x88B5
            unsigned char eth_type[] = {0x88, 0xB5};

            std::memcpy(frame, mac_dest, 6);
            std::memcpy(frame + 6, mac_src, 6);
            std::memcpy(frame + 12, eth_type, 2);
            std::memcpy(frame + 14, payload_ptr, payload_len);

            // Mise à jour de l'adresse MAC destination pour le sendto
            std::memcpy(sll.sll_addr, mac_dest, 6);

            // Envoi réel
            size_t total_len = 14 + payload_len;
            ssize_t sent = sendto(this->sock, frame, total_len, 0, 
                                (struct sockaddr*)&this->sll, sizeof(this->sll));

            if (sent > 0) {
                std::cout << "[RawSender] Succès : " << sent << " octets envoyés." << std::endl;
                status_ptr[0] = 1; // OK
            } else {
                perror("[RawSender] Erreur sendto");
                status_ptr[0] = 0; // Erreur
            }

            return spu::runtime::status_t::SUCCESS;
        });
    }

    ~RawSender() { if (sock >= 0) close(sock); }
};

// ==========================
// MODULE 3 : Vérificateur de Statut
// ==========================
class SendStatusModule : public spu::module::Stateful
{
public:
    SendStatusModule() : spu::module::Stateful()
    {
        this->set_name("SendStatusModule");
        auto& t = this->create_task("check");
        this->create_socket_in<uint8_t>(t, "send_status", 1);

        this->create_codelet(t, [](spu::module::Module&, spu::runtime::Task& t, const size_t)
        {
            uint8_t status = *static_cast<const uint8_t*>(t[0].get_dataptr());
            if (status) 
                std::cout << "[Status] VERDICT: ENVOI RÉUSSI" << std::endl;
            else 
                std::cerr << "[Status] VERDICT: ÉCHEC" << std::endl;
            
            return spu::runtime::status_t::SUCCESS;
        });
    }
};

// ==========================
// MAIN
// ==========================
int main()
{
    const std::string net_interface = "enp3s0"; // Adapte le nom si nécessaire
    const size_t max_size = 1500;

    try {
        FrameGenerator generator(max_size);
        RawSender sender(net_interface, max_size);
        SendStatusModule checker;

        // Connexions des modules
        sender["send::payload"] = generator["generate::payload"];
        sender["send::length"]  = generator["generate::length"];
        checker["check::send_status"] = sender["send::send_status"];

        // Création de la séquence 
        spu::runtime::Sequence seq(generator("generate"), 1);

        std::cout << "--- Démarrage de la séquence ---" << std::endl;
        
        // On exécute 5 fois (ou remplace par un while(true) avec un cin.get())
        for(int i = 0; i < 5; i++) {
            std::cout << "\nCycle " << i+1 << ":" << std::endl;
            seq.exec_step();
        }

    } catch (const std::exception& e) {
        std::cerr << "ERREUR FATALE: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}