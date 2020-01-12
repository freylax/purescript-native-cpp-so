#include "purescript.h"
#include "dlfcn.h"

using namespace purescript;

namespace {
  class DLObjects {
  public:
    DLObjects( const std::string& file) : dlobj( NULL)
    {
      dlobj = dlopen( file.c_str(), RTLD_NOW | RTLD_GLOBAL);
      if( dlobj == NULL )
	throw std::runtime_error( dlerror());
    }
    
    auto dlsym( const std::string& sym_) -> boxed {
      // get the c function name
      std::string sym( "PS_" );
      for (auto i = sym_.cbegin(), end = sym_.cend(); i != end; i++) {
	auto c = *i;
	if (c == '\'') sym.append( "Prime_");
	else {
	  if (c == '.') c = '_';
	  sym.push_back( c);
	}
      }
      typedef const boxed& (*PF_boxed)();
      auto f = reinterpret_cast<PF_boxed>( ::dlsym( dlobj, sym.c_str()));  // NOLINT
      if (!f) throw std::runtime_error( dlerror());
      return boxed( f() );
    }
    
    void dlclose() { if( dlobj != NULL ) { ::dlclose( dlobj); dlobj = NULL; } }

    ~DLObjects() { dlclose(); }
  private:
    void* dlobj;
  };
}

extern "C" auto PS_Posix_Dlfcn_dlopen() -> const boxed& {
  static const boxed _ = [](const boxed& file_) -> boxed {
    return [=]() -> boxed {
      const auto& file = unbox<string>( file_);
      return box<DLObjects*>( new DLObjects( file));
    };
  };
  return _;
};

extern "C" auto PS_Posix_Dlfcn_dlsym() -> const boxed& {
  static const boxed _ = [](const boxed& dlobj_) -> boxed {
    return [=](const boxed& sym_) -> boxed { // symbol
      return [=](const boxed&) -> boxed {    // drop proxy
	return [=]() -> boxed {              // effect
	  const auto& dlobj = unbox< DLObjects*>( dlobj_);
	  const auto& sym = unbox<string>( sym_);
	  return dlobj->dlsym( sym);
	};
      };
    };
  };
  return _;
};

extern "C" auto PS_Posix_Dlfcn_dlclose() -> const boxed& {
  static const boxed _ = [](const boxed& dlobj_) -> boxed {
    return [=]() -> boxed {              // effect
      const auto& dlobj = unbox< DLObjects*>( dlobj_);
      dlobj->dlclose();
      return boxed();
    };
  };
  return _;
};


