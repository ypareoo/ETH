#include <iostream>
#include <streampu.hpp>

// Inclusion de nos modules locaux
#include "FrameGenerator.hpp"
#include "RawSender.hpp"
#include "RawReceiver.hpp"
#include "PayloadWriter.hpp"

int main()
{
    const std::string net_interface = "enp3s0"; 
    const size_t max_size = 1500;

    try {
        FrameGenerator generator(max_size);
        RawSender sender(net_interface, max_size);
        RawReceiver receiver(net_interface, max_size);
        PayloadWriter writer;

        sender["send::payload"] = generator["generate::payload"];
        sender["send::length"]  = generator["generate::length"];
        
        receiver["receive::trigger"] = sender["send::send_status"];
        
        writer["write::payload"] = receiver["receive::payload"];
        writer["write::length"]  = receiver["receive::length"];

        spu::runtime::Sequence seq(generator("generate"), 1);

        std::cout << "--- Démarrage de la séquence ---" << std::endl;
        for(int i = 0; i < 5; i++) {
            std::cout << "\n--- Cycle " << i+1 << " ---" << std::endl;
            seq.exec_step();
        }

    } catch (const std::exception& e) {
        std::cerr << "ERREUR FATALE: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}