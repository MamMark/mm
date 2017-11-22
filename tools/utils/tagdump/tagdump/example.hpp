/* starting in /media/psf/Home/tag/mm/mm/include
 */
#include "../../include/mm_types.h"
#include "../../../prod/tos/system/panic.h"

namespace ns{
  typedef char C;
  typedef char field [50];
  typedef struct {
    int8_t   foo;
    uint8_t  bar;
  } fdtype_t;
  
  typedef struct {
    int len;                 /* size 18, 0x12 */
    fdtype_t  dtype;
  }  fdt_event_t;

#include "typed_data.h"
}
