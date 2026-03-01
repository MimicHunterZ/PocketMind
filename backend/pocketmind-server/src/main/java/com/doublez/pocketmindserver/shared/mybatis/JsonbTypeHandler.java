package com.doublez.pocketmindserver.shared.mybatis;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;
import org.apache.ibatis.type.MappedJdbcTypes;
import org.apache.ibatis.type.MappedTypes;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Map;

/**
 * PostgreSQL JSONB 专用 TypeHandler。
 * 使用 Types.OTHER + JSON 字符串通知 JDBC 驱动以 jsonb 类型写入，
 * 无需直接依赖 org.postgresql.util.PGobject（runtime scope 即可）。
 */
@MappedTypes(Map.class)
@MappedJdbcTypes(JdbcType.OTHER)
public class JsonbTypeHandler extends BaseTypeHandler<Map<String, Object>> {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i,
                                    Map<String, Object> parameter,
                                    JdbcType jdbcType) throws SQLException {
        try {
            // Types.OTHER 让 PostgreSQL JDBC 驱动将字符串识别为 jsonb
            ps.setObject(i, MAPPER.writeValueAsString(parameter), Types.OTHER);
        } catch (JsonProcessingException e) {
            throw new SQLException("无法将 Map 序列化为 JSON: " + e.getMessage(), e);
        }
    }

    @Override
    public Map<String, Object> getNullableResult(ResultSet rs, String columnName) throws SQLException {
        return parse(rs.getString(columnName));
    }

    @Override
    public Map<String, Object> getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        return parse(rs.getString(columnIndex));
    }

    @Override
    public Map<String, Object> getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        return parse(cs.getString(columnIndex));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parse(String json) throws SQLException {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            return MAPPER.readValue(json, Map.class);
        } catch (JsonProcessingException e) {
            throw new SQLException("无法将 JSON 反序列化为 Map: " + e.getMessage(), e);
        }
    }
}
