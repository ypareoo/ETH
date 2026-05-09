#ifndef PAYLOADWRITER_HPP
#define PAYLOADWRITER_HPP

#include <streampu.hpp>

class PayloadWriter : public spu::module::Stateful
{
public:
    PayloadWriter();
};

#endif