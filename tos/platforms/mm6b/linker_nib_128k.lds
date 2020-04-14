/*
 * Copyright (c) 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/*
 * GCC toolchain Linker script for NIB images.
 * New Image Block (NIB), Bank 1 (upper 128K)
 * Normal operating arena.
 *
 * max flash 128Ki (half of available).
 * 0x0002_0000 - 0x0003_ffff
 * vectors at    0x0002_0000
 * image meta at 0x0002_0140
 */

MEMORY {
    MAIN_FLASH (RX) : ORIGIN = 0x00020000, LENGTH = 128K
    INFO_FLASH (RX) : ORIGIN = 0x00200000, LENGTH = 16K
    SRAM_CODE  (RWX): ORIGIN = 0x01000000, LENGTH = 64K
    SRAM_DATA  (RW) : ORIGIN = 0x20000000, LENGTH = 64K
}

REGION_ALIAS("REGION_TEXT",      MAIN_FLASH);
REGION_ALIAS("REGION_INFO",      INFO_FLASH);
REGION_ALIAS("REGION_BSS",       SRAM_DATA);
REGION_ALIAS("REGION_DATA",      SRAM_DATA);
REGION_ALIAS("REGION_STACK",     SRAM_DATA);
REGION_ALIAS("REGION_HEAP",      SRAM_DATA);
REGION_ALIAS("REGION_ARM_EXIDX", MAIN_FLASH);
REGION_ALIAS("REGION_ARM_EXTAB", MAIN_FLASH);

SECTIONS {

    /* section for the interrupt vector area                                 */
    PROVIDE (_vector_base = ORIGIN(REGION_TEXT));

    .intvecs (_vector_base) : AT (_vector_base) {
        __vectors_start__ = .;
        __image_start__   = .;
        KEEP (*(.vectors))
        __vectors_end__ = .;
    } > REGION_TEXT

    /*
     * image_meta hold image_info which needs to immediately
     * follow the vectors.  The msp432 has 0x140 bytes of
     * vectors.  If this changes the linker will bitch because
     * we hardcode where the image_meta starts.
     */

    PROVIDE (_image_meta_base = ORIGIN(REGION_TEXT) + 0x140);
    .image_meta (_image_meta_base) : AT (_image_meta_base) {
        __image_meta_start__ = .;
        KEEP (*(.image_meta))
        __image_meta_end__ = .;
    } > REGION_TEXT

    /* The following three sections show the usage of the INFO flash memory  */
    /* INFO flash memory is intended to be used for the following            */
    /* device specific purposes:                                             */
    /* Flash mailbox for device security operations                          */
    PROVIDE (_mailbox_base_address = ORIGIN(REGION_INFO));

    .flashMailbox (_mailbox_base_address) : AT (_mailbox_base_address) {
        KEEP (*(.flashMailbox))
    } > REGION_INFO

    /* TLV table for device identification and characterization              */
    PROVIDE (_tlv_base_address = 0x00201000);

    .tlvTable (_tlv_base_address) (NOLOAD) : AT (_tlv_base_address) {
        KEEP (*(.tlvTable))
    } > REGION_INFO

    /* BSL area for device bootstrap loader                                  */
    PROVIDE (_bsl_base_address = 0x00202000);

    .bslArea (_bsl_base_address) : AT (_bsl_base_address) {
        KEEP (*(.bslArea))
    } > REGION_INFO

    .text : {
        . = ALIGN(4);
        __text_start__ = .;
        KEEP (*(.text))
        *(.text.*)
        KEEP (*(.ctors))
        . = ALIGN(4);
        KEEP (*(.dtors))
        . = ALIGN(4);
        KEEP (*(.init_array*))
        *(.init)
        *(.fini*)
        . = ALIGN(4);
    } > REGION_TEXT AT> REGION_TEXT

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > REGION_TEXT AT> REGION_TEXT

    .ARM.exidx : {
        __exidx_start = .;
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
        __exidx_end = .;
    } > REGION_ARM_EXIDX AT> REGION_ARM_EXIDX

    .ARM.extab : {
        KEEP (*(.ARM.extab* .gnu.linkonce.armextab.*))
    } > REGION_ARM_EXTAB AT> REGION_ARM_EXTAB

    __etext = .;
    __text_end__ = .;


    /*
     * OverWatch Control Block lives at the base of RAM.
     *
     * overwatch_data must be NOLOAD to prevent objcopy from filling
     * a very large gap with zeros.
     */
    PROVIDE (_overwatch_data_base = ORIGIN(REGION_DATA));
    .overwatch_data (_overwatch_data_base) (NOLOAD) : AT (_overwatch_data_base) {
        __overwatch_data_start__ = .;
        KEEP (*(.overwatch_data))
        __overwatch_data_end__ = .;
    } > REGION_DATA

    .noinit (NOLOAD) : {
        KEEP (*(.noinit))
     } > REGION_DATA

    .data : ALIGN(4) {
        . = ALIGN (4);
        __data_load__  = LOADADDR (.data);
        __data_start__ = .;
        KEEP (*(.data))
        KEEP (*(.data*))
        . = ALIGN (4);
        __data_end__ = .;
    } > REGION_DATA AT> REGION_TEXT

    .image_end (NOLOAD) : {
        __image_end__ = . ;
    } > REGION_TEXT AT> REGION_TEXT

    .bss (NOLOAD): {
        . = ALIGN (4);
        __bss_start__ = .;
        *(.shbss)
        KEEP (*(.bss))
        *(.bss.*)
        *(COMMON)
        . = ALIGN (4);
        __bss_end__ = .;
    } > REGION_BSS AT> REGION_BSS

    .heap : {
        KEEP (*(.heap))
    } > REGION_HEAP AT> REGION_HEAP

    .crash_stack  (NOLOAD) : ALIGN(8) {
        __crash_stack_start__ = .;
        KEEP(*(.crash_stack))
     } > REGION_STACK AT> REGION_STACK
     __crash_stack_top__ = .;


    .stack (NOLOAD) : ALIGN(8) {
        __stack_start__ = .;
        KEEP(*(.stack))
    } > REGION_STACK AT> REGION_STACK

    __StackTop__ = ORIGIN(REGION_STACK) + LENGTH(REGION_STACK);
    PROVIDE(__stack = __StackTop__);

    PROVIDE(__image_length__ = __image_end__ - __image_start__);
    .imagelen (__image_length__) : AT (__image_length__) {
    } > REGION_TEXT

}
