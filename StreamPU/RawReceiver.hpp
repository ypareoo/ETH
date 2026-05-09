#ifndef RAWRECEIVER_HPP
#define RAWRECEIVER_HPP

#include <streampu.hpp>
#include <string>
#include <sys/socket.h>
#include <net/if.h>
#include <netpacket/packet.h>

class RawReceiver : public spu::module::Stateful
{
private:
    int sock;
    struct ifreq ifr;
    struct sockaddr_ll sll;

public:
    RawReceiver(const std::string& interface, size_t max_payload_size);
    ~RawReceiver();
};

#endif