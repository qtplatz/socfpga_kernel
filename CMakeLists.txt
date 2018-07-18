#
cmake_minimum_required ( VERSION 3.7 )  # for GREATER_EQUAL
cmake_policy( SET CMP0020 NEW )
cmake_policy( SET CMP0042 NEW )
cmake_policy( SET CMP0053 NEW )

project ( socfpga_kernel )

set ( REMOTE_HOST "de0" CACHE STRING "Target host address for install-remote" )
set ( REMOTE_USER "" CACHE STRING "Target host login name for install-remote" )

if ( REMOTE_USER )
  set ( REMOTE_ACCOUNT ${REMOTE_USER}@${REMOTE_HOST} )
else()
  set ( REMOTE_ACCOUNT ${REMOTE_HOST} )
endif()

set ( CMAKE_EXPORT_COMPILE_COMMANDS ON )

if (NOT DEFINED CMAKE_SUPPRESS_DEVELOPER_WARNINGS)
  set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS 1 CACHE INTERNAL "No dev warnings")
endif()

list( APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/Modules" )

#--- read config.sh ---
file( STRINGS ${CMAKE_SOURCE_DIR}/config.sh configs )
foreach( i ${configs} )
  string( REGEX MATCHALL "[^=]+=.+$" config ${i} )
  string( REGEX REPLACE "([^=]+)=(.+$)" "\\1" key ${i} )
  if ( ${key} MATCHES "^(KERNELRELEASE|cross_target|target|target_device)$" )
    string( REGEX REPLACE "([^=]+)=(.+$)" "\\2" value ${i} )
    set( ${key} ${value} )
  endif()
endforeach()

set ( MAKE make )
set ( DOWNLOADS $ENV{HOME}/Downloads )
set ( KERNEL_SOURCE ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE} )
set ( TOOLS ${CMAKE_SOURCE_DIR}/scripts )

if ( NOT EXISTS ${DOWNLOADS}/linux-${KERNELRELEASE}.tar.xz )
  file ( DOWNLOAD
    http://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNELRELEASE}.tar.xz
    ${DOWNLOADS}/linux-${KERNELRELEASE}.tar.xz
    SHOW_PROGRESS
    )
endif()

add_custom_command( 
  OUTPUT ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}
  COMMAND tar xvf ${DOWNLOADS}/linux-${KERNELRELEASE}.tar.xz
  DEPENDS ${DOWNLOADS}/linux-${KERNELRELEASE}.tar.xz
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )

add_custom_command( 
  OUTPUT ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/arch/arm/boot/zImage
  COMMAND cp ${CMAKE_SOURCE_DIR}/config-${KERNELRELEASE} ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/.config
  COMMAND ${MAKE} -C ${KERNEL_SOURCE} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j4 zImage
  COMMAND ${MAKE} -C ${KERNEL_SOURCE} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j4 all
  DEPENDS ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}
  )

add_custom_target(
  zImage ALL DEPENDS ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/arch/arm/boot/zImage
  )

add_custom_target(
  menuconfig
  COMMAND ${MAKE} -C ${KERNEL_SOURCE} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}
  )

add_custom_target( install-remote DEPENDS ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/arch/arm/boot/zImage
  COMMAND cmake -E echo scp -p ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/arch/arm/boot/zImage ${REMOTE_ACCOUNT}:
  COMMAND scp -p ${CMAKE_BINARY_DIR}/linux-${KERNELRELEASE}/arch/arm/boot/zImage ${REMOTE_ACCOUNT}:  
  COMMAND cmake -E echo ssh ${REMOTE_ACCOUNT} bash -s '<' ${CMAKE_SOURCE_DIR}/remote-deploy.sh
  COMMAND ssh ${REMOTE_ACCOUNT} bash -s < ${CMAKE_SOURCE_DIR}/remote-deploy.sh
  VERBATIM
  )

message( STATUS "--------------------------------------------" )
message( STATUS "KERNELRELEASE   = " ${KERNELRELEASE} )
message( STATUS "KERNEL_SOURCE   = " ${KERNEL_SOURCE} )
message( STATUS "cross_target    = " ${cross_target} )
message( STATUS "target_device   = " ${target_device} )
message( STATUS "DOWNLOADS       = " ${DOWNLOADS} )
message( STATUS "--------------------------------------------" )
