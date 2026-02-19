package com.doublez.pocketmindserver.chat.infra.persistence.message;

import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;
import org.apache.ibatis.type.MappedJdbcTypes;
import org.apache.ibatis.type.MappedTypes;

import java.sql.*;
import java.util.*;

/**
 * PostgreSQL UUID[] ↔ Java List<UUID> 转换处理器
 */
@MappedTypes(List.class)
@MappedJdbcTypes(JdbcType.ARRAY)
public class UuidArrayTypeHandler extends BaseTypeHandler<List<UUID>> {

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, List<UUID> parameter, JdbcType jdbcType)
            throws SQLException {
        Array array = ps.getConnection().createArrayOf("uuid", parameter.toArray());
        ps.setArray(i, array);
    }

    @Override
    public List<UUID> getNullableResult(ResultSet rs, String columnName) throws SQLException {
        return toList(rs.getArray(columnName));
    }

    @Override
    public List<UUID> getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        return toList(rs.getArray(columnIndex));
    }

    @Override
    public List<UUID> getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        return toList(cs.getArray(columnIndex));
    }

    private List<UUID> toList(Array array) throws SQLException {
        if (array == null) {
            return Collections.emptyList();
        }
        Object[] objs = (Object[]) array.getArray();
        if (objs == null) {
            return Collections.emptyList();
        }
        List<UUID> result = new ArrayList<>(objs.length);
        for (Object obj : objs) {
            if (obj instanceof UUID uuid) {
                result.add(uuid);
            } else if (obj != null) {
                result.add(UUID.fromString(obj.toString()));
            }
        }
        return result;
    }
}
