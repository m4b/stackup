//
//  main.swift
//  stackup
//
//  Created by x86 on 2/15/15.
//  Copyright (c) 2015 m4b. All rights reserved.
//

import Foundation

//todo add process args
//Process.arguments
if (Process.arguments.isEmpty || Process.arguments.count < 3){
    println("stackup <path to binary> <stacksize>")
    exit(EXIT_FAILURE)
}

//println("got args: \(Process.arguments)")

if let path = String(UTF8String: Process.arguments[1])?.stringByExpandingTildeInPath {
    let fd = fopen(path, "r+")
    println("opening: \(path)")
    
    let stack_arg = Process.arguments.last!
    let stacksize = UInt64(stack_arg.hasPrefix("0x") ? strtoll(C_ARGV[2], nil, 16) : atoll(C_ARGV[2]))
    
    //    let stacksize = UInt64(stack_arg, nil, 16))
    println("stacksize: \(stacksize)")
    if fd == nil {
        println("could not find binary at: \(path)")
        exit(EXIT_FAILURE)
    }
    
    // cause we're not running xcode 6.3 with swift 1.2... yet
    var mh:mach_header_64 = mach_header_64(magic: 0x0, cputype: 0x0, cpusubtype: 0x0, filetype: 0x0, ncmds: 0x0, sizeofcmds: 0x0, flags: 0x0, reserved: 0x0)
    
    let count = fread(&mh, UInt(sizeof(mach_header_64)), 1,fd)
    
    if mh.magic != MH_MAGIC_64 {
        println("error; file is not a mach-o binary")
        exit(EXIT_FAILURE)
    }
    
    //    let stacksize = UInt64(0x10000)
    
    var offset:UInt32 = 0x0
    for i in 0 ... mh.ncmds {
        var lc = load_command(cmd: 0x0, cmdsize: 0x0)
        
        offset = offset + lc.cmdsize * i
        let count = fread(&lc, UInt(sizeof(load_command)), 1, fd)
        
        //        println("lc.cmd: \(lc.cmd)")
        
        switch lc.cmd {
        case 0x28 | LC_REQ_DYLD: // because LC_MAIN isn't defined in swift MachO/loader module?... derp
            fseek(fd, Int(-sizeof(load_command)), SEEK_CUR) // such hacks
            var epc = entry_point_command(cmd: 0x0, cmdsize: 0x0, entryoff: 0x0, stacksize: 0x0)
            let count_read = fread(&epc, UInt(sizeof(entry_point_command)), 1, fd)
            
            epc.stacksize = stacksize
            
            fseek(fd, Int(-sizeof(entry_point_command)), SEEK_CUR) // uuuughgghhg
            
            
            let count_write = fwrite(&epc, UInt(sizeof(entry_point_command)), 1, fd)
            
            if (count_write != 1){
                fclose(fd)
                println("error: wrote \(count_write) num elements; something went wrong")
                exit(EXIT_FAILURE)
            }
            
            println("success changing stack to: \(epc.stacksize)")
            
            fclose(fd)
            exit(EXIT_SUCCESS)
            break
        default:
            fseek(fd, (Int(lc.cmdsize) - Int(sizeof(load_command))), SEEK_CUR)
            continue
        }
    }
    
    fclose(fd)
    println("LC_MAIN not found in binary")
    exit(EXIT_SUCCESS)
    
    
}else{
    println("invalid path")
    exit(EXIT_FAILURE)
}

    