#ifndef RAWSENDER_HPP
#define RAWSENDER_HPP

#include <streampu.hpp>
#include <string>
#include <sys/socket.h>
#include <net/if.h>
#include <netpacket/packet.h>

class RawSender : public spu::module::Stateful
{
private:
    int sock;
    struct ifreq ifr;
    struct sockaddr_ll sll;

public:
    RawSender(const std::string& interface, size_t max_payload_size);
    ~RawSender();
};

#endif