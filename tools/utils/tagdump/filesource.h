#ifndef FILE_SOURCE_H
#define FILE_SOURCE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns: file descriptor for input file
     -1 for failure
 */
int open_file_source(const char *filename);

/* Effects: reads packet from serial forwarder on file descriptor fd
   Returns: the packet read (in newly allocated memory), and *len is
     set to the packet length
*/
dt_header_t *read_file_dblk(int fd, int *len);

#ifdef __cplusplus
}
#endif

#endif
