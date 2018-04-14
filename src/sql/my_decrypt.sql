CREATE DEFINER=`root`@`localhost` FUNCTION `my_decrypt`(instr varchar(3000)) RETURNS varchar(2000) CHARSET utf8
    DETERMINISTIC
    COMMENT 'base64解码函数'
BEGIN
	DECLARE base64_string VARCHAR(64) BINARY DEFAULT 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
	-- 返回结果解码后的字符串
	DECLARE ret VARCHAR(2000) DEFAULT '';
	-- 解码后字节二进制数据，用于utf-8编码
	DECLARE bin_decrypt_bytes BLOB DEFAULT '';
  -- 获取原编码后的字节数组
	DECLARE encrypted_bytes VARCHAR(6000) DEFAULT '';
	BEGIN
		DECLARE idx_i INT DEFAULT 0;
    -- 输入字符串长度
		DECLARE len_instr INT DEFAULT 0;
		-- 遍历每个字符
		DECLARE instr_per_char CHAR(1) DEFAULT '';
		-- 字符在base64_string的位置为原字符编码后的值
		DECLARE locat_in_base64 INT	DEFAULT 0;
		
		SET len_instr = CHAR_LENGTH(instr) -1;
		IF (len_instr + 1) % 4 <> 0 THEN
			RETURN NULL;
		END IF;
		-- 获取原字符编码后的字节值
		BEGIN
			get_encrypted_bytes_loop:
			WHILE idx_i <= len_instr DO
				SET instr_per_char = SUBSTR(instr, idx_i + 1, 1);
				IF instr_per_char <> '=' THEN
					SET locat_in_base64 = LOCATE(BINARY instr_per_char, base64_string) - 1;
					IF locat_in_base64 < 0 THEN
						RETURN NULL;
					END IF;
					SET encrypted_bytes = CONCAT(CONCAT(encrypted_bytes, locat_in_base64), ' ');
				ELSE
					SET encrypted_bytes = CONCAT(CONCAT(encrypted_bytes, '='), ' ');
				END IF;
				SET idx_i = idx_i + 1;
			END WHILE get_encrypted_bytes_loop;
		END;
		-- 解码
		BEGIN
			-- 8位二进制
			DECLARE byte_default VARCHAR(8) DEFAULT '00000000';
			DECLARE right_bytes VARCHAR(6000) DEFAULT '';
			DECLARE encryt_len INT DEFAULT 0;
			DECLARE idx_j INT DEFAULT 0;

			SET right_bytes = encrypted_bytes;
			SET encryt_len = CHAR_LENGTH(encrypted_bytes) - CHAR_LENGTH(REPLACE(encrypted_bytes, ' ', '')) -1;
			decode2bytes_loop:
			WHILE idx_j <= encryt_len DO
				BEGIN
					DECLARE decrypt_bytes INT DEFAULT 0;
					DECLARE decrypt_tmp INT DEFAULT 0;
					DECLARE idx_k TINYINT DEFAULT 0;
					DECLARE locate_space INT DEFAULT 0;
					DECLARE left_bytes VARCHAR(3) DEFAULT '';
					DECLARE left_bytes2 VARCHAR(3) DEFAULT '';
					DECLARE bin_de_tmp VARCHAR(8) default '';
					DECLARE len_bin_tmp TINYINT DEFAULT 0;
					
					decode2bytes_sub_loop:
					WHILE idx_k <= 2 DO
						SET locate_space = LOCATE(' ', right_bytes);
						SET left_bytes = LEFT(right_bytes, locate_space - 1);
						SET right_bytes = SUBSTR(right_bytes, locate_space + 1);
						SET left_bytes2 = LEFT(right_bytes, LOCATE(' ', right_bytes) - 1);
						
						IF (idx_j + idx_k + 1) <= encryt_len AND left_bytes2 <> '=' THEN
							SET decrypt_tmp =  (left_bytes2 & 0xff) >> (2 + 2 * (2 - (idx_k + 1)));
							SET decrypt_bytes = (((left_bytes & 0xff) << (2 + 2 * idx_k) & 0xff)) | decrypt_tmp;
							-- 获取所有字符ASC值转为二进制，不足8位高位补0
							SET bin_de_tmp = BIN(decrypt_bytes);
							SET len_bin_tmp = 8 - CHAR_LENGTH(bin_de_tmp);
							SET bin_de_tmp = CONCAT(SUBSTR(byte_default, 1, len_bin_tmp), bin_de_tmp);
							SET bin_decrypt_bytes = CONCAT(bin_decrypt_bytes, bin_de_tmp);
						END IF;
						SET idx_k = idx_k + 1;
					END WHILE decode2bytes_sub_loop;
				END;
				SET right_bytes = SUBSTR(right_bytes, LOCATE(' ', right_bytes) + 1);
				SET idx_j = idx_j + 4;
			END WHILE decode2bytes_loop;
		END;
	END;

	-- utf-8编码字节
	BEGIN
		DECLARE idx_current INT DEFAULT 1;
		DECLARE len_bin_decrypt_bytes INT DEFAULT 0;
		DECLARE len_one_head TINYINT DEFAULT 0;
		DECLARE bin_tmp TINYINT DEFAULT 0;
		DECLARE bin_utf_8 VARCHAR(48) DEFAULT '';
		DECLARE char_utf_8 VARCHAR(1) DEFAULT '';
		
		SET len_bin_decrypt_bytes = CHAR_LENGTH(bin_decrypt_bytes);
		utf_8_encode_main_loop:
		WHILE idx_current <= len_bin_decrypt_bytes DO
			
			BEGIN
				DECLARE idx_l INT DEFAULT 0;
				utf_8_encode_sub_loop:
				WHILE TRUE DO
					SET bin_tmp = SUBSTR(bin_decrypt_bytes, idx_current + idx_l, 1);
					IF bin_tmp = 1 THEN
						-- utf-8汉字以1开头，以多少个1开头表示占用多少字节
						SET len_one_head = len_one_head + 1;
					ELSE
						-- utf-8 以0开头的字符，占用1个字节
						LEAVE utf_8_encode_sub_loop;
					END IF;
					SET idx_l = idx_l + 1;
				END WHILE utf_8_encode_sub_loop;
				-- 一个字符占用多个字节的情况
				IF len_one_head > 0 THEN
					SET bin_utf_8 = SUBSTR(bin_decrypt_bytes, idx_current, len_one_head * 8);
					SET idx_current = idx_current + len_one_head * 8;
				ELSE
					-- 一个字节占用1个字节的情况
					SET bin_utf_8 = SUBSTR(bin_decrypt_bytes, idx_current, 8);
					SET idx_current = idx_current + 8;
				END IF;
				SET len_one_head = 0;
				-- 将二进制编码为字符
				SET char_utf_8 = CHAR(CONV(bin_utf_8, 2, 10));
				SET ret = CONCAT(ret, char_utf_8);
			END;
		END WHILE utf_8_encode_main_loop;
	END;
	
	RETURN ret;
END