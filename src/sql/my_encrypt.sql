CREATE DEFINER=`root`@`localhost` FUNCTION `my_encrypt`(instr varchar(2000)) RETURNS varchar(6000) CHARSET utf8
    DETERMINISTIC
    COMMENT 'base64编码函数'
BEGIN
	-- 返回结果 编码后的字符串
	DECLARE ret VARCHAR(6000) DEFAULT '';
	-- 输入字符的字节数组 以' '隔开
	DECLARE bytes_instr VARCHAR(6000) DEFAULT '';
	
	BEGIN
		-- 输入字符长度
		DECLARE len_instr INT DEFAULT 0;
		DECLARE tmp_str VARCHAR(1) DEFAULT '';
		DECLARE idx_i INT DEFAULT 0;
		-- 字符的ASCII值
		DECLARE ord_value INT DEFAULT 0;
		-- 字符的字节数
		DECLARE oct_len TINYINT DEFAULT 0;
		
		SET len_instr = CHAR_LENGTH(instr) - 1;
		-- 获取字符串的字节数组循环
		get_bytes_all_loop:
		WHILE idx_i <= len_instr DO
			SET tmp_str = SUBSTR(instr,idx_i + 1, 1);
			SET ord_value = ORD(tmp_str);
			SET oct_len = OCTET_LENGTH(tmp_str);
			
			BEGIN
				-- 字符的字节
				DECLARE ord_value_byte INT DEFAULT 0;
				DECLARE idx_j INT DEFAULT 0;
				SET idx_j = oct_len - 1;
				-- 获取每个字符的字节值循环，转为utf-8多个字节表示一个字符
				get_bytes_one_loop:
				WHILE idx_j >= 0 DO
					-- ASCII码一共规定了128个字符的编码
					IF ord_value > 127 THEN
						SET ord_value_byte = (ord_value >> (8 *idx_j)) & 0xff;
						SET bytes_instr = CONCAT(CONCAT(bytes_instr, ord_value_byte), ' ');
					ELSE
						SET bytes_instr = CONCAT(CONCAT(bytes_instr, ord_value), ' ');
					END IF;
					SET idx_j = idx_j - 1;
				END WHILE get_bytes_one_loop;
			END;
			SET idx_i = idx_i + 1;
		END WHILE get_bytes_all_loop;
	
	END;

	BEGIN
		DECLARE base64_string VARCHAR(64) DEFAULT 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
		-- 按' '取出字节后剩下的字节数组
		DECLARE substr_right VARCHAR(6000)	DEFAULT '';
		-- 一共有多少个字节
		DECLARE bytes_len INT DEFAULT 0;
		DECLARE idx_k INT DEFAULT 0;
		-- 获取有多少个字节（除去' '后的差值）
		SET bytes_len = CHAR_LENGTH(bytes_instr) - CHAR_LENGTH(REPLACE(bytes_instr, ' ', '')) - 1;
		SET substr_right = bytes_instr;
		-- 编码循环，以每6位编码
		encrypt_loop:
		WHILE idx_k <= bytes_len DO
			BEGIN
				-- 看作四个字节的数组
				DECLARE ened_bytes VARCHAR(16) DEFAULT '';
				-- 8位——>6位后剩下的
				DECLARE last_bytes INT DEFAULT 0x00;
				BEGIN
					-- ' '所在的位置，用于切割
					DECLARE locate_space INT DEFAULT 0;
					-- 使用' '分割出来的一个字节
					DECLARE substr_left INT	DEFAULT 0;
					DECLARE ened_bytes_tmp INT DEFAULT 0;
					DECLARE idx_l TINYINT DEFAULT 0;
					encrypt_sub_loop:
					WHILE idx_l <= 2 DO
						IF (idx_k + idx_l) <= bytes_len THEN
							SET locate_space = LOCATE(' ', substr_right);
							SET substr_left = LEFT(substr_right, locate_space - 1);
							SET substr_right = SUBSTR(substr_right, locate_space + 1);
							-- 6位二进制值
							SET ened_bytes_tmp = (substr_left >> (2 + 2 * idx_l)) | last_bytes;
							SET last_bytes = ((substr_left << (2 + 2 * (2 - idx_l))) & 0xff) >> 2;
							SET ened_bytes = CONCAT(CONCAT(ened_bytes, ened_bytes_tmp), ' ');
						ELSE
							-- 剩下位数不为6的倍数
							SET ened_bytes = CONCAT(CONCAT(ened_bytes, last_bytes), ' ');
							SET last_bytes = 64;
						END IF;
						SET idx_l = idx_l + 1;
					END WHILE encrypt_sub_loop;
				END;
				-- 赋值第四个字节
				SET ened_bytes = CONCAT(CONCAT(ened_bytes, last_bytes), ' ');
			
				BEGIN
					DECLARE idx_m INT	DEFAULT 0;
					DECLARE locate_space2 INT DEFAULT 0;
					-- 使用' '分割出来的一个字节
					DECLARE bytes_left INT DEFAULT 0;
					-- 按' '取出字节后剩下的字节数组
					DECLARE bytes_right VARCHAR(32) DEFAULT '';
					SET bytes_right = ened_bytes;
					bytes2string_loop:
					WHILE idx_m <= 3 DO
						SET locate_space2 = LOCATE(' ', bytes_right);
						SET bytes_left = LEFT(bytes_right, locate_space2 - 1);
						SET bytes_right = SUBSTR(bytes_right, locate_space2 + 1);
						
						IF bytes_left <= 63 THEN
							SET ret = CONCAT(ret, SUBSTR(base64_string, bytes_left + 1, 1));
						ELSE
							SET ret = CONCAT(ret, '=');
						END IF;
						SET idx_m = idx_m + 1;
					END WHILE bytes2string_loop;
				END;
				SET ened_bytes = '';
			END;
			SET idx_k = idx_k + 3;
		END WHILE encrypt_loop;
	END;
	RETURN ret;
END