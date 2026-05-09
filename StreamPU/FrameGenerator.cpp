#include "FrameGenerator.hpp"
#include <iostream>
#include <cstring>
#include <fstream>

FrameGenerator::FrameGenerator(size_t max_size) : spu::module::Stateful()
{
    this->set_name("FrameGenerator");
    auto& t = this->create_task("generate");
    this->create_socket_out<uint8_t>(t, "payload", max_size);
    this->create_socket_out<uint32_t>(t, "length", 1);

    this->create_codelet(t, [](spu::module::Module&, spu::runtime::Task& t, const size_t)
    {
        auto* payload_ptr = static_cast<uint8_t*>(t[0].get_dataptr());
        auto* length_ptr  = static_cast<uint32_t*>(t[1].get_dataptr());

        std::ifstream fich{"src/payload.txt"};
        std::string s;
        if(fich) {
            fich >> s;
        } else {
            std::cout << "ERREUR dans la lecture de payload.txt" << std::endl;
            s = "\xAA\xAA\xAA\xAA\xAA\xAA";
        }
        
        const char* data = s.c_str();
        uint32_t len = s.size();

        std::memcpy(payload_ptr, data, len);
        length_ptr[0] = len;

        std::cout << "[FrameGenerator] Payload prêt" << std::endl;
        return spu::runtime::status_t::SUCCESS;
    });
}