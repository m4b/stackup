//
//  main.swift
//  stackup
//
//  Created by x86 on 2/15/15.
//  Copyright (c) 2015 m4b. All rights reserved.
//

import Foundation

//todo add process args
//CommandLine.arguments
if (CommandLine.arguments.isEmpty || CommandLine.arguments.count < 3){
    print("stackup <path to binary> <stacksize>")
    exit(EXIT_FAILURE)
}

//print("got args: \(CommandLine.arguments)")

let path = NSString(string: CommandLine.arguments[1]).expandingTildeInPath
let fd = fopen(path, "r+")
print("opening: \(path)")

let stack_arg = CommandLine.arguments.last!
let stacksize = UInt64(stack_arg.hasPrefix("0x") ? strtoll(CommandLine.unsafeArgv[2], nil, 16) : atoll(CommandLine.unsafeArgv[2]))

//    let stacksize = UInt64(stack_arg, nil, 16))
print("stacksize: \(stacksize)")
if fd == nil {
    print("could not find binary at: \(path)")
    exit(EXIT_FAILURE)
}

func fixBinary(filePointer: UnsafeMutablePointer<FILE>, offset: Int) -> Bool
{
    fseek(fd, offset, SEEK_SET)
    var mh:mach_header_64 = mach_header_64(magic: 0x0, cputype: 0x0, cpusubtype: 0x0, filetype: 0x0, ncmds: 0x0, sizeofcmds: 0x0, flags: 0x0, reserved: 0x0)
    let count = fread(&mh, Int(MemoryLayout.size(ofValue: mh)), 1,fd)

    if count != 1 || (mh.magic != MH_MAGIC_64 && mh.magic != MH_CIGAM_64)
    {
        print("no mach-o binary at offset \(offset)")
        return false
    }

    let byteSwapped = mh.magic == MH_CIGAM_64;
    if(byteSwapped)
    {
        mh.ncmds = mh.ncmds.byteSwapped
    }

    for _ in 0 ..< mh.ncmds {
        var lc = load_command(cmd: 0x0, cmdsize: 0x0)
        let count = fread(&lc, Int(MemoryLayout.size(ofValue: lc)), 1, fd)
        if(count == 1 && byteSwapped)
        {
            lc.cmd = lc.cmd.byteSwapped;
            lc.cmdsize = lc.cmdsize.byteSwapped;
        }
        
        switch lc.cmd {
        case 0x28 | LC_REQ_DYLD: // because LC_MAIN isn't defined in swift MachO/loader module?... derp
            fseek(fd, Int(-MemoryLayout.size(ofValue: lc)), SEEK_CUR) // such hacks
            var epc = entry_point_command(cmd: 0x0, cmdsize: 0x0, entryoff: 0x0, stacksize: 0x0)
            let count_read = fread(&epc, Int(MemoryLayout.size(ofValue: epc)), 1, fd)

            if(count_read == 1)
            {
                epc.stacksize = stacksize
                if(byteSwapped) {
                    epc.stacksize = epc.stacksize.byteSwapped
                }
                
                fseek(fd, Int(-MemoryLayout.size(ofValue: epc)), SEEK_CUR) // uuuughgghhg
                
                let count_write = fwrite(&epc, Int(MemoryLayout.size(ofValue: epc)), 1, fd)
                if (count_write != 1){
                    fclose(fd)
                    print("error: wrote \(count_write) num elements; something went wrong")
                    return false
                }
                
                print("success changing stack to: \(epc.stacksize)")
                return true
            }
            break
        default:
            fseek(fd, (Int(lc.cmdsize) - Int(MemoryLayout.size(ofValue: lc))), SEEK_CUR)
            continue
        }
    }
    return false
}

var fat: fat_header = fat_header(magic: 0x0, nfat_arch: 0x0)
let count = fread(&fat, MemoryLayout.size(ofValue: fat), 1, fd)

if(count == 1 && (fat.magic == FAT_MAGIC || fat.magic == FAT_CIGAM))
{
    // fat binary header
    let byteSwapped = (fat.magic == FAT_CIGAM)
    if(byteSwapped) {
        fat.nfat_arch = fat.nfat_arch.byteSwapped;
    }

    print("Fat binary with \(fat.nfat_arch) architectures...")
    for _ in 0 ..< fat.nfat_arch {
        var arch: fat_arch = fat_arch(cputype: 0x0, cpusubtype: 0x0, offset: 0x0, size: 0x0, align: 0x0)
        let archRead = fread(&arch, MemoryLayout.size(ofValue: arch), 1, fd)
        let pos = ftell(fd);

        if(archRead == 1) {
            if(byteSwapped) {
                arch.cputype = arch.cputype.byteSwapped
                arch.cpusubtype = arch.cpusubtype.byteSwapped
                arch.offset = arch.offset.byteSwapped
                arch.size = arch.size.byteSwapped
            }

            print("Found cputype: \(arch.cputype)")

            if(!fixBinary(filePointer: fd!, offset: Int(arch.offset))) {
                print("  failed to fix!")
            }
        }

        fseek(fd, pos, SEEK_SET)

    }   

} else if(count == 1 && (fat.magic == MH_MAGIC_64 || fat.magic == MH_CIGAM_64 ) )
{
    // non fat binary
    if(!fixBinary(filePointer: fd!, offset: 0))
    {
        print("error; failed to fix binary!")
        fclose(fd)
        exit(EXIT_FAILURE)
    }
} else
{
    print("error; not a fat binary nor mach-o binary!")
    fclose(fd)
    exit(EXIT_FAILURE);
}
fclose(fd)
print("Stacksize updated")
exit(EXIT_SUCCESS)
