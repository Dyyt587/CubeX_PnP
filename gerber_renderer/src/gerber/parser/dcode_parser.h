#pragma once
#include "parser.h"

class Gerber;

class DCodeParser : public Parser {
public:
	DCodeParser(Gerber& gerber);

	bool Run() override;
	bool EndOfFile() override;

private:
	Gerber& gerber_;
};