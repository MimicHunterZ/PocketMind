package com.doublez.pocketmindserver.memory.infra.persistence;

import com.doublez.pocketmindserver.memory.domain.MemoryEvidence;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
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
import java.util.List;

/**
 * PostgreSQL JSONB TypeHandler — 序列化 / 反序列化 List&lt;MemoryEvidence&gt;。
 *
 * <p>使用 Types.OTHER 让 JDBC 驱动以 jsonb 写入，避免 VARCHAR→jsonb 隐式转换失败。
 */
@MappedTypes(List.class)
@MappedJdbcTypes(JdbcType.OTHER)
public class MemoryEvidenceJsonbTypeHandler extends BaseTypeHandler<List<MemoryEvidence>> {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final TypeReference<List<MemoryEvidence>> TYPE_REF = new TypeReference<>() {};

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i,
                                    List<MemoryEvidence> parameter,
                                    JdbcType jdbcType) throws SQLException {
        try {
            ps.setObject(i, MAPPER.writeValueAsString(parameter), Types.OTHER);
        } catch (JsonProcessingException e) {
            throw new SQLException("无法将 List<MemoryEvidence> 序列化为 JSON: " + e.getMessage(), e);
        }
    }

    @Override
    public List<MemoryEvidence> getNullableResult(ResultSet rs, String columnName) throws SQLException {
        return parse(rs.getString(columnName));
    }

    @Override
    public List<MemoryEvidence> getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        return parse(rs.getString(columnIndex));
    }

    @Override
    public List<MemoryEvidence> getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        return parse(cs.getString(columnIndex));
    }

    private List<MemoryEvidence> parse(String json) throws SQLException {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            return MAPPER.readValue(json, TYPE_REF);
        } catch (JsonProcessingException e) {
            throw new SQLException("无法将 JSON 反序列化为 List<MemoryEvidence>: " + e.getMessage(), e);
        }
    }
}
