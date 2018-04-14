/*
 * base64encrypt.cpp
 *
 *  Created on: 2018年1月16日
 *      Author: BloodFly
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <mysql.h>

#define MYDLL extern "C" __declspec(dllexport)

extern "C" {
/*编码*/
MYDLL my_bool udfbase64encode_init(UDF_INIT* initid, UDF_ARGS* args, char* message);
MYDLL void udfbase64encode_deinit(UDF_INIT* initid);
MYDLL char *udfbase64encode(UDF_INIT *initid, UDF_ARGS *args, char *result, unsigned long *ret_length, char *is_null, char *error);
/*解码*/
MYDLL my_bool udfbase64decode_init(UDF_INIT* initid, UDF_ARGS* args, char* message);
MYDLL void udfbase64decode_deinit(UDF_INIT* initid);
MYDLL char *udfbase64decode(UDF_INIT *initid, UDF_ARGS *args, char *result, unsigned long *ret_length, char *is_null, char *error);
}

static const int RANGE = 0xff;
static const char base64_table[] = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
		'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
		'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
		'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
		'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
		'\0' };
static short reverse_table[128];
static short is_init = 0;
static char base64_pad = '=';

/**
 * 编码函数执行前的初始化
 */
my_bool udfbase64encode_init(UDF_INIT* initid, UDF_ARGS* args, char* message) {
	if (args->arg_count != 1) {
		strcpy(message,
				"Wrong arguments to udfbase64encode, requires one arguments");
		return 1;
	}

	if (args->arg_type[0] != STRING_RESULT) {
		args->arg_type[0] = STRING_RESULT;
	}

	return 0;
}
/**
 * 用于编码函数执行时申请内存的释放
 */
void udfbase64encode_deinit(UDF_INIT* initid) {
	if (initid->ptr)
		free(initid->ptr);
}

/**
 * base64编码
 */
char *udfbase64encode(UDF_INIT *initid, UDF_ARGS *args, char *result,
		unsigned long *ret_length, char *is_null, char *error) {
	const char *current = args->args[0];
	const unsigned long arg_len = args->lengths[0];
	unsigned long ret_len = 0;
	// 参数字符长度为0或不为字符串
	if (arg_len <= 0 || args->arg_type[0] != STRING_RESULT) {
		*is_null = 1;
		*ret_length = 0;
		return 0;
	}
	// 参数为空时
	if (!args || !args->args[0]) {
		*is_null = 1;
		*ret_length = 0;
		return 0;
	}
	// 为编码后的字符串申请内存空间
	if (!(result = (char*) malloc(
			sizeof(char) * ((arg_len + 3 - arg_len % 3) * 4 / 3 + 1)))) {
		// 内存申请失败的情况
		*is_null = 1;
		*error = 1;
		*ret_length = 0;
		return 0;
	}
	// 用于内存释放
	if (initid->ptr) {
		free(initid->ptr);
	}
	initid->ptr = result;
	// 每三个字节进行编码
	for (unsigned int i = 0; i < arg_len; i += 3) {
		short enBytes[4] = { 0, 0, 0, 0 };
		short tmp = 0x00;

		for (unsigned int k = 0; k <= 2; k++) {
			if ((i + k) < arg_len) {
				enBytes[k] = (((int) current[i + k] & RANGE) >> (2 + 2 * k)) | tmp;
				tmp = (((int) current[i + k] & RANGE) << (2 + 2 * (2 - k)) & RANGE) >> 2;
			} else {
				enBytes[k] = tmp;
				tmp = 64;
			}
		}
		enBytes[3] = tmp;
		for (int k = 0; k <= 3; k++) {
			if (enBytes[k] <= 63) {
				result[ret_len++] = base64_table[enBytes[k]];
			} else {
				result[ret_len++] = base64_pad;
			}
		}
	}
	result[ret_len] = '\0';
	*ret_length = ret_len;
	return result;
}


/**
 * 解码函数执行前的初始化
 */
my_bool udfbase64decode_init(UDF_INIT* initid, UDF_ARGS* args, char* message) {
	if (args->arg_count != 1) {
		strcpy(message,
				"Wrong arguments to udfbase64decode, requires one arguments");
		return 1;
	}

	if (args->arg_type[0] != STRING_RESULT) {
		args->arg_type[0] = STRING_RESULT;
	}

	if (!is_init) {
		memset(reverse_table, -1, sizeof(reverse_table));
		for (short i = 0; i < 64; i++) {
			reverse_table[(int) (base64_table[i])] = i;
		}
		is_init = 1;
	}
	return 0;
}

/**
 * 用于解码函数执行时申请内存的释放
 */
void udfbase64decode_deinit(UDF_INIT* initid) {
	if (initid->ptr)
		free(initid->ptr);
}

/**
 * base64解码
 */
char *udfbase64decode(UDF_INIT *initid, UDF_ARGS *args, char *result,
		unsigned long *ret_length, char *is_null, char *error) {
	const char *current = args->args[0];
	const unsigned long arg_len = args->lengths[0];
	// 参数字符长度为0或不为字符串
	if (arg_len <= 0 || args->arg_type[0] != STRING_RESULT) {
		*is_null = 1;
		*ret_length = 0;
		return 0;
	}
	if (!args || !args->args[0]) {
		*is_null = 1;
		*ret_length = 0;
		return 0;
	}
	// 字符串长度不为4的倍数
	if (arg_len % 4 != 0) {
		*is_null = 1;
		*ret_length = 0;
		return 0;
	}

	// 为处理结果申请内存空间
	if (!(result = (char*) malloc(sizeof(char) * (arg_len / 4 * 3) + 1))) {
		// 内存申请失败的情况
		*is_null = 1;
		*error = 1;
		*ret_length = 0;
		return 0;
	}
	// 用于最后释放申请的内存
	if (initid->ptr) {
		free(initid->ptr);
	}
	initid->ptr = result;
	char *result_curent = result;
	// 把bas64的4个字节转为原来的3个字节
	int ret_len = 0;
	for (unsigned int i = 0; i < arg_len; i += 4) {
		short temp;
		for (unsigned int k = 0; k <= 2; k++) {
			// bas64以外的字符直接返回NULL
			if (reverse_table[(short) current[i + k]] < 0 && current[i + k] != base64_pad) {
				*is_null = 1;
				*ret_length = 0;
				return 0;
			}
			if ((i + k + 1) < arg_len && reverse_table[(short)current[i + k + 1]] >= 0) {
				temp = ((short) reverse_table[(short)current[i + k + 1]] & RANGE) >> (2 + 2 * (2 - (k + 1)));
				result_curent[ret_len++] = ((reverse_table[(short)current[i + k]] & RANGE) << (2 + 2 * k) & RANGE) | temp;
			}
		}
	}
	result_curent[ret_len] = '\0';
	*ret_length = ret_len;
	return result;
}
