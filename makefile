all : pb.so
cur_path:=$(shell pwd)
pb.so : 
	cd $(cur_path)/protobufluaint64 && make

clean :
	cd $(cur_path)/protobufluaint64 && make clean