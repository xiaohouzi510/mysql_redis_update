all : pb.so

pb.so : libpb/pb.cpp 
	g++ -g -shared -fPIC -o lib/$@ $^ -ldl

clean :
	rm -rf lib/pb.so