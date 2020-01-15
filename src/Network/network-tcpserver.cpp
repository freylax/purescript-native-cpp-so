/**
   This is a wrapper to the simple server
   written by
   Copyright (C) 2015 Bastian Rieck 
   at git@github.com:Pseudomanifold/SimpleServer.git
*/

#include "purescript.h"

#include <errno.h>
#include <string.h>

#include <arpa/inet.h>
#include <netinet/in.h>

#include <sys/types.h>
#include <sys/socket.h>

#include <unistd.h>

#include <algorithm>
#include <future>
#include <memory>
#include <stdexcept>
#include <string>
#include <functional>
#include <mutex>
#include <vector>
#include <iostream>

using namespace purescript;

namespace {

  class Server;

  class Socket
  {
  public:
    Socket( int fileDescriptor, Server& server );
    ~Socket();
    
    int fileDescriptor() const;
    
    void close();
    void write( const std::string& data );    
    std::string read();
    
    Socket( const Socket& )            = delete;
    Socket& operator=( const Socket& ) = delete;
    
  private:
    int _fileDescriptor = -1;
    Server& _server;
  };
  
  class Server
  {
  public:
    Server();
    ~Server();
    void setBacklog( int backlog );
    void setPort( int port );
    void close();
    void listen();

    template <class F> void onAccept( F&& f ) { _handleAccept = f; }
    template <class F> void onRead( F&& f ) { _handleRead = f; }
    void close( int fileDescriptor );

  private:
    int _backlog =  1;
    int _port    = -1;
    int _socket  = -1;
    
    std::function< void ( std::weak_ptr<Socket> socket ) > _handleAccept;
    std::function< void ( std::weak_ptr<Socket> socket ) > _handleRead;
    std::vector< std::shared_ptr<Socket> > _clientSockets;
    std::vector<int> _staleFileDescriptors;
    std::mutex _staleFileDescriptorsMutex;
  };

  Server::Server() {}
  Server::~Server() { std::cout << "~Server" <<std::endl; this->close(); }

  void Server::setBacklog( int backlog ) { _backlog = backlog; }

  void Server::setPort( int port ) { _port = port; }

  void Server::close()
  {
    if( _socket )
      ::close( _socket );
    
    for( auto&& clientSocket : _clientSockets )
      clientSocket->close();
    
    _clientSockets.clear();
  }
  
  void Server::listen()
  {
    _socket = socket( AF_INET, SOCK_STREAM, 0 );

    if( _socket == -1 )
      throw std::runtime_error( std::string( strerror( errno ) ) );

    {
      int option = 1;

      setsockopt( _socket,
		  SOL_SOCKET,
		  SO_REUSEADDR,
		  reinterpret_cast<const void*>( &option ),
		  sizeof( option ) );
    }

    sockaddr_in socketAddress;

    std::fill( reinterpret_cast<char*>( &socketAddress ),
	       reinterpret_cast<char*>( &socketAddress ) + sizeof( socketAddress ),
	       0 );

    socketAddress.sin_family      = AF_INET;
    socketAddress.sin_addr.s_addr = htonl( INADDR_ANY );
    socketAddress.sin_port        = htons( _port );

    {
      int result = bind( _socket,
			 reinterpret_cast<const sockaddr*>( &socketAddress ),
			 sizeof( socketAddress ) );

      if( result == -1 )
	throw std::runtime_error( std::string( strerror( errno ) ) );
    }

    {
      int result = ::listen( _socket, _backlog );

      if( result == -1 )
	throw std::runtime_error( std::string( strerror( errno ) ) );
    }

    fd_set masterSocketSet;
    fd_set clientSocketSet;

    FD_ZERO( &masterSocketSet );
    FD_SET( _socket, &masterSocketSet );

    int highestFileDescriptor = _socket;

    while( 1 )
      {
	clientSocketSet = masterSocketSet;

	int numFileDescriptors = select( highestFileDescriptor + 1,
					 &clientSocketSet,
					 nullptr,   // no descriptors to write into
					 nullptr,   // no descriptors with exceptions
					 nullptr ); // no timeout

	if( numFileDescriptors == -1 )
	  break;

	// Will be updated in the loop as soon as a new client has been
	// accepted. This saves us from modifying the variable *during*
	// the loop execution.
	int newHighestFileDescriptor = highestFileDescriptor;

	for( int i = 0; i <= highestFileDescriptor; i++ )
	  {
	    if( !FD_ISSET( i, &clientSocketSet ) )
	      continue;

	    // Handle new client
	    if( i == _socket )
	      {
		sockaddr_in clientAddress;
		auto clientAddressLength = sizeof(clientAddress);

		int clientFileDescriptor = accept( _socket,
						   reinterpret_cast<sockaddr*>( &clientAddress ),
						   reinterpret_cast<socklen_t*>( &clientAddressLength ) );

		if( clientFileDescriptor == -1 )
		  break;

		FD_SET( clientFileDescriptor, &masterSocketSet );
		newHighestFileDescriptor = std::max( highestFileDescriptor, clientFileDescriptor );

		auto clientSocket = std::make_shared<Socket>( clientFileDescriptor, *this );

		if( _handleAccept )
		  auto result = std::async( std::launch::async, _handleAccept, clientSocket );

		_clientSockets.push_back( clientSocket );
	      }

	    // Known client socket
	    else
	      {
		char buffer[2] = {0,0};

		// Let's attempt to read at least one byte from the connection, but
		// without removing it from the queue. That way, the server can see
		// whether a client has closed the connection.
		int result = recv( i, buffer, 1, MSG_PEEK );

		if( result <= 0 )
		  {
		    // It would be easier to use erase-remove here, but this leads
		    // to a deadlock. Instead, the current socket will be added to
		    // the list of stale sockets and be closed later on.
		    this->close( i );
		  }
		else
		  {
		    auto itSocket = std::find_if( _clientSockets.begin(), _clientSockets.end(),
						  [&] ( std::shared_ptr<Socket> socket )
						  {
						    return socket->fileDescriptor() == i;
						  } );

		    if( itSocket != _clientSockets.end() && _handleRead )
		      auto result = std::async( std::launch::async, _handleRead, *itSocket );
		  }
	      }
	  }

	// Update the file descriptor if a new client has been accepted in
	// the loop above.
	highestFileDescriptor = std::max( newHighestFileDescriptor, highestFileDescriptor );

	// Handle stale connections. This is in an extra scope so that the
	// lock guard unlocks the mutex automatically.
	{
	  std::lock_guard<std::mutex> lock( _staleFileDescriptorsMutex );

	  for( auto&& fileDescriptor : _staleFileDescriptors )
	    {
	      FD_CLR( fileDescriptor, &masterSocketSet );
	      ::close( fileDescriptor );
	    }

	  _staleFileDescriptors.clear();
	}
      }
  }

  void Server::close( int fileDescriptor )
  {
    std::lock_guard<std::mutex> lock( _staleFileDescriptorsMutex );

    _clientSockets.erase( std::remove_if( _clientSockets.begin(), _clientSockets.end(),
					  [&] ( std::shared_ptr<Socket> socket )
					  {
					    return socket->fileDescriptor() == fileDescriptor;
					  } ),
			  _clientSockets.end() );
    
    _staleFileDescriptors.push_back( fileDescriptor );
  }

  Socket::Socket( int fileDescriptor, Server& server )
    : _fileDescriptor( fileDescriptor )
    , _server( server )
  {
  }

  Socket::~Socket() {}

  int Socket::fileDescriptor() const
  {
    return _fileDescriptor;
  }
  
  void Socket::close()
  {
    _server.close( _fileDescriptor );
  }
  
  void Socket::write( const std::string& data )
  {
    auto result = send( _fileDescriptor,
			reinterpret_cast<const void*>( data.c_str() ),
			data.size(),
			0 );
    
    if( result == -1 )
      throw std::runtime_error( std::string( strerror( errno ) ) );
  }

  std::string Socket::read()
  {
    std::string message;
    
    char buffer[256] = { 0 };
    ssize_t numBytes = 0;
    
    while( ( numBytes = recv( _fileDescriptor, buffer, sizeof(buffer), MSG_DONTWAIT ) ) > 0 )
      {
	buffer[numBytes]  = 0;
	message          += buffer;
      }
    
    return message;
  }
}

extern "C" auto PS_Network_TcpServer_write() -> const boxed& {
  static const boxed _ = [](const boxed& socket_) -> boxed {
    return [=](const boxed& s_) -> boxed { // string
      return [=]() -> boxed { // effect
	auto& socket = const_cast< Socket&>(unbox<Socket>( socket_));
	const auto& s = unbox<std::string>( s_);
	socket.write( s);
	return boxed();
      };
    };
  };
  return _;
};

extern "C" auto PS_Network_TcpServer_read() -> const boxed& {
  static const boxed _ = [](const boxed& socket_) -> boxed {
    return [=]() -> boxed { // effect
      auto& socket = const_cast< Socket&>( unbox<Socket>( socket_));
      return boxed( socket.read());
    };
  };
  return _;
};

extern "C" auto PS_Network_TcpServer_close() -> const boxed& {
  static const boxed _ = [](const boxed& socket_) -> boxed {
    return [=]() -> boxed { // effect
      auto& socket = const_cast< Socket&>( unbox<Socket>( socket_));
      socket.close();
      return boxed();
    };
  };
  return _;
};

extern "C" auto PS_Network_TcpServer_createServer() -> const boxed& {
  static const boxed _ = [](const boxed& port_) -> boxed {
    return [=]() -> boxed { // effect
      const auto& port = unbox<int>( port_);
      auto server = std::make_shared<Server>();
      server->setPort( port);
      return boxed( server);
    };
  };
  return _;
};

extern "C" auto PS_Network_TcpServer_onRead() -> const boxed& {
  static const boxed _ = [](const boxed& server_) -> boxed {
    return [=](const boxed& f) -> boxed { //callback
      return [=]() -> boxed { // effect
	// we need a const cast here because the Server
	// will be modified...
	auto& server = const_cast<Server&>( unbox< Server>( server_));
	server.onRead( [=] ( std::weak_ptr<Socket> socket )
	{
	  if( auto s = socket.lock() ) {
	    f( s)();
	  }
	});
	return boxed();
      };
    };
  };
  return _;
};

extern "C" auto PS_Network_TcpServer_listen() -> const boxed& {
  static const boxed _ = [](const boxed& server_) -> boxed {
    return [=]() -> boxed { // effect
      auto& server = const_cast<Server&>( unbox< Server>( server_));
      server.listen();
      return boxed();
    };
  };
  return _;
};

