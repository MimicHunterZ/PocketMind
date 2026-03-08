package com.doublez.pocketmindserver.note.infra.persistence.category;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/**
 * categories 表 MyBatis Mapper
 */
@Mapper
public interface CategoryMapper extends BaseMapper<CategoryModel> {

		/**
		 * 软删除分类并更新 updated_at（用于增量同步）。
		 */
		@Update("""
						UPDATE categories
						SET is_deleted = TRUE,
								updated_at = #{updatedAt}
						WHERE id = #{id}
							AND user_id = #{userId}
							AND is_deleted = FALSE
						""")
		int softDeleteByIdAndUserId(@Param("id") long id,
																@Param("userId") long userId,
																@Param("updatedAt") long updatedAt);

		/**	按 UUID 软删除分类并更新 updated_at（绕过 @TableLogic，用于同步）。
		 */
		@Update("""
						UPDATE categories
						SET is_deleted = TRUE,
								updated_at = #{updatedAt}
						WHERE uuid = #{uuid}::uuid
							AND user_id = #{userId}
						""")
		int softDeleteByUuidAndUserId(@Param("uuid") java.util.UUID uuid,
																	@Param("userId") long userId,
																	@Param("updatedAt") long updatedAt);

		/**	 同步回填 server_version。
		 */
		@Update("""
					UPDATE categories
					   SET server_version = #{serverVersion}
					 WHERE uuid    = #{uuid}::uuid
					   AND user_id = #{userId}
					""")
		int updateServerVersion(@Param("uuid") java.util.UUID uuid,
												@Param("userId") long userId,
												@Param("serverVersion") long serverVersion);}