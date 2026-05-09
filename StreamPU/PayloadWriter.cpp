#include "PayloadWriter.hpp"
#include <iostream>
#include <fstream>

PayloadWriter::PayloadWriter() : spu::module::Stateful()
{
    this->set_name("PayloadWriter");
    auto& t = this->create_task("write");
    
    this->create_socket_in<uint8_t>(t, "payload", 1500); 
    this->create_socket_in<uint32_t>(t, "length", 1);

    this->create_codelet(t, [](spu::module::Module&, spu::runtime::Task& t, const size_t)
    {
        auto* payload_ptr = static_cast<const uint8_t*>(t[0].get_dataptr());
        uint32_t len      = *static_cast<const uint32_t*>(t[1].get_dataptr());

        if (len == 0) return spu::runtime::status_t::SUCCESS; 

        std::ofstream outfile("src/reception.txt", std::ios_base::app);
        if (outfile.is_open()) {
            outfile.write(reinterpret_cast<const char*>(payload_ptr), len);
            outfile << "\n";
            outfile.close();
            std::cout << "[PayloadWriter] Payload ajouté dans src/reception.txt" << std::endl;
        } else {
            std::cerr << "[PayloadWriter] ERREUR: Impossible d'ouvrir src/reception.txt" << std::endl;
            return spu::runtime::status_t::FAILURE;
        }
        return spu::runtime::status_t::SUCCESS;
    });
}