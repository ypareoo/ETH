#ifndef FRAMEGENERATOR_HPP
#define FRAMEGENERATOR_HPP

#include <streampu.hpp>
#include <string>

class FrameGenerator : public spu::module::Stateful
{
public:
    FrameGenerator(size_t max_size);
};

#endif