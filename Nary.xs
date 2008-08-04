/* This file is part of the Sub::Nary Perl module.
 * See http://search.cpan.org/dist/Sub::Nary/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef mPUSHi
# define mPUSHi(I) PUSHs(sv_2mortal(newSViv(I)))
#endif /* !mPUSHi */

/* --- XS ------------------------------------------------------------------ */

MODULE = Sub::Nary            PACKAGE = Sub::Nary

PROTOTYPES: ENABLE

void
tag(SV *op)
PROTOTYPE: $
CODE:
 ST(0) = sv_2mortal(newSVuv(SvIV(SvRV(op))));
 XSRETURN(1);

void
null(SV *op)
PROTOTYPE: $
PREINIT:
 OP *o;
CODE:
 o = INT2PTR(OP *, SvIV(SvRV(op)));
 ST(0) = sv_2mortal(newSVuv(o == NULL));
 XSRETURN(1);

void
scalops()
PROTOTYPE:
PREINIT:
 U32 cxt;
 int i, count = 0;
CODE:
 cxt = GIMME_V;
 if (cxt == G_SCALAR) {
  for (i = 0; i < OP_max; ++i) {
   count += (PL_opargs[i] & (OA_RETSCALAR | OA_RETINTEGER)) != 0;
  }
  EXTEND(SP, 1);
  mPUSHi(count);
  XSRETURN(1);
 } else if (cxt == G_ARRAY) {
  for (i = 0; i < OP_max; ++i) {
   if (PL_opargs[i] & (OA_RETSCALAR | OA_RETINTEGER)) {
    const char *name = PL_op_name[i];
    XPUSHs(sv_2mortal(newSVpvn_share(name, strlen(name), 0)));
    ++count;
   }
  }
  XSRETURN(count);
 }

