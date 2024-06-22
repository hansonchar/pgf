
# Where Lua is installed
LUAPATH=/opt/homebrew/opt/lua@5.3

LUAINCLUDES = $(LUAPATH)/include/lua

# Where ogdf is installed
OGDFINCLUDES = $(OGDFPATH)/include
OGDFLIBPATH = $(OGDFPATH)/lib

# Where the shared libraries should be installed (base dir)
INSTALLDIR=/Users/hchar/lib

# If you need special flags:
# MYCFLAGS=-fPIC -std=c++11
MYCFLAGS=-fPIC

# MYLDFLAGS=-lOGDF -lCOIN -llua -lstdc++
# MYLDFLAGS=-llua -lstdc++
# MYLDFLAGS=-llua -lCOIN -stdlib=libc++
# MYLDFLAGS=-llua -lCOIN -lstdc++
MYLDFLAGS=-llua -lstdc++

# Link flags for building a shared library
SHAREDFLAGS=-L$(OGDFLIBPATH) -L$(LUALIBPATH) -shared
# SHAREDFLAGS=-L$(LUALIBPATH) -shared

# Architecture flags:
# ARCHFLAGS=-arch arm64

CC=gcc
CPP=g++
