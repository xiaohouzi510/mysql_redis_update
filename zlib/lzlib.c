#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "include/zlib.h"


static int lzlib(lua_State *L)
{
	return 0;
}

static const struct luaL_Reg my_lib[] = {
	{"zlib",lzlib},
	{NULL,NULL},
};

int luaopen_zlib(lua_State *L)
{
	// luaL_newlib(L,my_lib);
	return 1;
}

int main(int argc,char *argv[])
{
	FILE *file = fopen("best_test.txt","rb");
	fseek(file,0,SEEK_END);
	uLong flen  = ftell(file);
	uLong clen  = 0;
	fseek(file,0,SEEK_SET);
	unsigned char *source = (unsigned char *)malloc((int)flen);
	unsigned char *target = (unsigned char *)malloc((int)(flen*2));
	fread(source,1,flen,file);
	fclose(file);
	int i = uncompress(target,&clen,source,flen);
	printf("%d %d\n",clen,i);
	return 0;
}