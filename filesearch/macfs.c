#include "env.h"
#include "global.h"
#include "fs_common.h"
#include "util.h"
#include "suffix.h"
#include <dirent.h>
#include <limits.h>

static pFileEntry initMacFile(const char *pathname, const struct stat *statptr, char *filename, pFileEntry parent, int i){
	int len = strlen(filename);
	NEW0_FILE(ret,len);
	ret->us.v.FileNameLength = len;
	ret->us.v.StrLen = utf8_to_wchar_len(filename,len);
	strncpy(ret->FileName,filename,len);
	if(S_ISDIR(statptr->st_mode)) {
		ret->ut.v.suffixType = SF_DIR;
		ret->us.v.dir = 1;
	}
    /*
	if(is_readonly_ffd(pfd)) ret->us.v.readonly = 1;
	if(is_hidden_ffd(pfd)) ret->us.v.hidden = 1;
	if(is_system_ffd(pfd)) ret->us.v.system = 1;
     */
	addChildren(parent,ret);
	SuffixProcess(ret,NULL);
	set_time(ret, statptr->st_mtime);
	if(IsDir(ret)){
		SET_SIZE(ret,0);
	}else{
		SET_SIZE(ret,file_size_shorten(statptr->st_size));
	}
	ALL_FILE_COUNT +=1;
	return ret;
}


static void dopath(char *fullpath, char *filename, pFileEntry parent, int i){
	struct stat		statbuf;
	if (lstat(fullpath, &statbuf) >= 0){
		pFileEntry self = initMacFile(fullpath, &statbuf, filename,parent,i);
		if(S_ISDIR(statbuf.st_mode)) {
			char *ptr;
			DIR *dp;
			ptr = fullpath + strlen(fullpath);	/* point to end of fullpath */
			*ptr++ = '/';
			*ptr = 0;
			if ((dp = opendir(fullpath)) != NULL) {
				struct dirent	*dirp;
				while ((dirp = readdir(dp)) != NULL) {
					if (strcmp(dirp->d_name, ".") == 0  || strcmp(dirp->d_name, "..") == 0) continue;
					strcpy(ptr, dirp->d_name);	/* append name after slash */
					dopath(fullpath, dirp->d_name,self,i);
				}
				ptr[-1] = 0;	/* erase everything from slash onwards */
				if (closedir(dp) < 0) printf("can't close directory %s", fullpath);
			}
		}
	}
}


int scanMac(pFileEntry root, int i){
	long len = pathconf("/", _PC_PATH_MAX);
	char *fullpath = (char *)malloc_safe(len);
	strncpy(fullpath, "/User", len);
	fullpath[len-1] = 0;
	printf("%d ,%s\n",len,fullpath);
	dopath(fullpath,"User",root,i);
	free_safe(fullpath);
	return ALL_FILE_COUNT;
}
