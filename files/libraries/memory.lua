-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local ffi = require("ffi")

local Memory = {}

if ffi.abi'64bit' then
	ffi.cdef([[
		typedef uint64_t __uint3264;
	]])
else
	ffi.cdef([[
		typedef uint32_t __uint3264;
	]])
end

ffi.cdef([[
	typedef void            VOID;
	typedef VOID            *LPVOID;
	typedef int             BOOL;
	typedef __uint3264      ULONG_PTR, *PULONG_PTR;
	typedef ULONG_PTR       SIZE_T, *PSIZE_T;
	typedef unsigned long   DWORD;
	typedef DWORD           *PDWORD;

	BOOL VirtualProtect(LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
]])

Memory.PAGE_NOACCESS          = 0x01
Memory.PAGE_READONLY          = 0x02
Memory.PAGE_READWRITE         = 0x04
Memory.PAGE_WRITECOPY         = 0x08
Memory.PAGE_EXECUTE           = 0x10
Memory.PAGE_EXECUTE_READ      = 0x20
Memory.PAGE_EXECUTE_READWRITE = 0x40
Memory.PAGE_EXECUTE_WRITECOPY = 0x80
Memory.PAGE_GUARD             = 0x100
Memory.PAGE_NOCACHE           = 0x200
Memory.PAGE_WRITECOMBINE      = 0x400

---Changes the protection on a region of committed pages in the virtual address space of the calling process.
---@param addr ffi.cdata*
---@param size integer
---@param newProtect integer
---@return ffi.cdata* oldProtect
function Memory.VirtualProtect(addr, size, newProtect)
	local oldProtect = ffi.new('DWORD[1]')
	if not ffi.C.VirtualProtect(addr, size, newProtect, oldProtect) then
		error(string.format("failed to call VirtualProtect(%s, %s, %s)", addr, size, newProtect))
	end

	return oldProtect
end

return Memory
