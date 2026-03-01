package com.doublez.pocketmindserver.asset.infra;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetMapper;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * AssetRepository 鐨?MyBatis-Plus 瀹炵幇銆?
 */
@Repository
public class AssetDBRepository implements AssetRepository {

    private final AssetMapper mapper;

    public AssetDBRepository(AssetMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void save(Asset asset) {
        int rows = mapper.insert(asset);
        if (rows != 1) {
            throw new BusinessException(
                    ApiCode.ATTACHMENT_SAVE_FAILED,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + asset.getUuid());
        }
    }

    @Override
    public Optional<Asset> findByUuidAndUserId(UUID uuid, long userId) {
        Asset model = mapper.selectOne(
                new LambdaQueryWrapper<Asset>()
                        .eq(Asset::getUuid, uuid)
                        .eq(Asset::getUserId, userId)
        );
        return Optional.ofNullable(model);
    }

    @Override
    public List<Asset> findByNoteUuidAndUserId(UUID noteUuid, long userId) {
        return mapper.selectList(
                new LambdaQueryWrapper<Asset>()
                        .eq(Asset::getNoteUuid, noteUuid)
                        .eq(Asset::getUserId, userId)
        );
    }

    @Override
    public boolean bindNoteUuid(UUID assetUuid, long userId, UUID noteUuid) {
        int rows = mapper.update(
                new LambdaUpdateWrapper<Asset>()
                        .eq(Asset::getUuid, assetUuid)
                        .eq(Asset::getUserId, userId)
                        .set(Asset::getNoteUuid, noteUuid)
        );
        return rows > 0;
    }
}

