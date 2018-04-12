
#include <platform_panic.h>

#ifndef __TAGNET_PANIC_H__
#define __TAGNET_PANIC_H__

/*
 * define the subsystem code for panic.
 *
 * typically this will be done in platform_panic.h but
 * if not let's not die.
 */
#ifndef PANIC_TAGNET
enum {
  __pcode_tagnet = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_TAGNET __pcode_tagnet
#endif

/*
 * autogenerate where codes, but first eat the
 * 0th (first one).
 */
#ifndef UQ_TAGNET_AUTOWHERE
#define UQ_TAGNET_AUTOWHERE "Tagnet.AutoWhere"
enum {
  __tagnet_autowhere_first = unique(UQ_TAGNET_AUTOWHERE),
};
#endif

#ifndef TAGNET_AUTOWHERE
#define TAGNET_AUTOWHERE unique(UQ_TAGNET_AUTOWHERE)
#endif

#endif   /* __TAGNET_PANIC_H__ */
