CXX		= g++

SRC_DIR		:= src
TB_SRC_DIR	:= tb_src
OBJ_DIR		:= obj

vpath %.cpp $(TB_SRC_DIR)
vpath %.h $(TB_SRC_DIR)

SRCS_SV		= $(wildcard $(SRC_DIR)/*.sv)
SRCS_CPP	= $(wildcard $(TB_SRC_DIR)/*.cpp)
EXE		= simulation.x

CXXFLAGS	= -Wall -Werror -g -O3
LDFLAGS		= -g
VFLAGS		= --sc --pins-uint8 --exe $(patsubst %, -CFLAGS %, $(CXXFLAGS))\
		  $(patsubst %, -LDFLAGS %, $(LDFLAGS)) --Mdir $(OBJ_DIR) --MP\
		  -o ../$(EXE)

all: $(EXE)

$(OBJ_DIR)/VMTwister.mk: $(SRCS_SV) $(SRCS_CPP)
	verilator $(VFLAGS) $^

$(EXE): $(OBJ_DIR)/VMTwister.mk
	make -C $(OBJ_DIR) -f VMTwister.mk

lint:
	verilator --lint-only -Wall $(SRCS_SV)

clean:
	$(RM) $(EXE)
	$(RM) -r $(OBJ_DIR)

.PHONY: lint clean all $(EXE)
