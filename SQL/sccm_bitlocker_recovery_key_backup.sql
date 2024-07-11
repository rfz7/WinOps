/*
	Копирование ключей восстановления Bitlocker в отдельную БД
*/

INSERT INTO CM_Bitlocker.dbo.BitlockerRecovery(id, Name, VolumeId, RecoveryKeyId, RecoveryKey, LastUpdateTime)

SELECT
	a1.Id,
	a1.Name,
	b1.VolumeId,
	c1.RecoveryKeyId,
	RecoveryAndHardwareCore.DecryptString(c1.RecoveryKey, DEFAULT) AS RecoveryKey,
	c1.LastUpdateTime
FROM
	CM_ABC.dbo.RecoveryAndHardwareCore_Machines a1
	inner join CM_ABC.dbo.RecoveryAndHardwareCore_Machines_Volumes b1 ON a1.Id = b1.MachineId
	inner join CM_ABC.dbo.RecoveryAndHardwareCore_Keys c1 ON b1.VolumeId = c1.VolumeId

WHERE NOT EXISTS
	(
	SELECT
		a2.Id,
		a2.Name,
		a2.VolumeId,
		a2.RecoveryKeyId,
		a2.RecoveryKey,
		a2.LastUpdateTime

	FROM
		CM_Bitlocker.dbo.BitlockerRecovery a2

	WHERE
		a2.Id = a1.id AND
		a2.Name = a1.Name AND
		a2.VolumeId = b1.VolumeId AND
		a2.RecoveryKeyId = c1.RecoveryKeyId AND
		a2.RecoveryKey = RecoveryAndHardwareCore.DecryptString(c1.RecoveryKey, DEFAULT) AND
		a2.LastUpdateTime = c1.LastUpdateTime
	)

