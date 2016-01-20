
#ifndef _WIN32_WINNT            // Specifies that the minimum required platform is Windows Vista.
#define _WIN32_WINNT 0x0600     // Change this to the appropriate value to target other versions of Windows.
#endif

#include <stdio.h>
#include <tchar.h>
#include <Windows.h>
#include <direct.h>
#include <errno.h>

BOOL LoadFile(TCHAR* FileName, BYTE** base, DWORD* size)
{
	HANDLE HF=CreateFile(FileName, GENERIC_READ, FILE_SHARE_WRITE|FILE_SHARE_READ,0,OPEN_EXISTING,0,0);

	if(HF == INVALID_HANDLE_VALUE)
	{
		_tprintf(TEXT("Error! Cannot open file %s\n"), FileName);
		exit(1);
	}

	DWORD wasread = 0;
	*size = GetFileSize(HF, NULL);
	*base = new BYTE[*size];
	if(!ReadFile(HF, *base, *size, &wasread, NULL) || wasread!=*size)
	{
		_tprintf(TEXT("Error! Cannot read file %s\n"), FileName);
		exit(1);
	}

	CloseHandle(HF);
	return true;
}

BOOL SaveFile(TCHAR* FileName, void* base, DWORD size)
{
	HANDLE HF=CreateFile(FileName, GENERIC_WRITE, FILE_SHARE_WRITE|FILE_SHARE_READ,0, CREATE_ALWAYS,0,0);

	if(HF == INVALID_HANDLE_VALUE)
	{
		_tprintf(TEXT("Error! Cannot create file %s\n"), FileName);
		exit(1);
	}

	DWORD written = 0;

	if(!::WriteFile(HF, base, size, &written, NULL) || written!=size)
	{
		_tprintf(TEXT("Error! Cannot write to file %s\n"), FileName);
		exit(1);
	}

	CloseHandle(HF);

	return true;
}

TCHAR buff[1024];

BOOL FileExists(LPCTSTR szPath)
{
  DWORD dwAttrib = GetFileAttributes(szPath);

  return (dwAttrib != INVALID_FILE_ATTRIBUTES && 
         !(dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

int _tmain(int argc, _TCHAR* argv[])
{
	BYTE *base = NULL, *part = NULL;
	DWORD sz, psz;

	base = (BYTE*)malloc(512);
	sz = 512;
	memset(base, 0, 512);
	strcpy_s((char*)base, 5, "BKHD");
	base[4] = 1;
	*(DWORD*)(base+16) = 1; // first partition offset

	if(argc<3)
	{
		_tprintf(_T("BK HDD split/combine utility.\n(c)2016, Sorg.\n\nusage: <hddfile> s|c\n"));
		return 1;
	}

	if(!_tcsicmp(argv[2], _T("c")))
	{
		int n = 0;
		int cnt = 0;
		while((cnt<64) && (n<200))
		{
			_stprintf_s(buff, _T("disk%03d.bkd"), n);
			if(FileExists(buff))
			{
				LoadFile(buff, &part, &psz);
				DWORD newpsz = (psz + 511) & ~511;
				base = (BYTE*)realloc(base, sz + newpsz);
				memcpy(base+sz, part, psz);
				DWORD blkoff = *(DWORD*)(base + 16 + (cnt*4));  // First Disk on HDD is C.
				blkoff += newpsz/512;
				cnt++;
				*(DWORD*)(base + 16 + (cnt*4)) = blkoff;
				sz +=newpsz;
			}

			n++;
		}

		SaveFile(argv[1], base, sz);
	}

	if(!_tcsicmp(argv[2], _T("s")))
	{
		LoadFile(argv[1], &base, &sz);
		for(int i=0; i<64; i++)
		{
			DWORD blkoff = *(DWORD*)(base + 16 + (i*4));
			DWORD blkend = *(DWORD*)(base + 16 + (i*4) + 4);
			if(blkoff && blkend) 
			{
				_stprintf_s(buff, _T("disk%03d.bkd"), i+2);
				SaveFile(buff, base + (blkoff<<9), (blkend - blkoff)<<9);
			}
		}
	}

	return 0;
}
