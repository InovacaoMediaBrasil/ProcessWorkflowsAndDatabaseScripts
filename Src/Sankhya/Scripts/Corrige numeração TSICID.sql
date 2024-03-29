DECLARE
@ATUAL INT,
@INI INT,
@NOMECID VARCHAR(20),
@DESCRICAOCORREIO CHAR(60),
@CODMUNFIS INT,
@SUSPEITADEFRAUDE VARCHAR(10),
@DTALTER DATETIME,
@UF INT

ALTER TABLE sankhya.TSICID NOCHECK CONSTRAINT ALL;
ALTER INDEX [AK_NOMECID_TSICID] ON sankhya.TSICID DISABLE;
ALTER INDEX [IX_CODMUNFIS_TSICID] ON sankhya.TSICID DISABLE;
ALTER TABLE sankhya.TGFPAR DISABLE TRIGGER ALL;

SET @ATUAL = 1;

WHILE(@ATUAL < (SELECT MAX(CODCID) + 1 FROM sankhya.TSICID))
BEGIN
	SELECT @ATUAL = MIN(CODCID) 
	FROM sankhya.TSICID WITH (NOLOCK)
	WHERE CODCID > @ATUAL;

	SELECT @INI = MAX(CODCID) + 1
	FROM sankhya.TSICID WITH (NOLOCK)
	WHERE CODCID < @ATUAL;

	SELECT	@NOMECID =			NOMECID, 
			@DESCRICAOCORREIO = DESCRICAOCORREIO, 
			@DTALTER =			DTALTER, 
			@CODMUNFIS =		CODMUNFIS, 
			@SUSPEITADEFRAUDE = AD_SUSPEITADEFRAUDE, 
			@UF =				UF
	FROM sankhya.TSICID WITH (NOLOCK) 
	WHERE CODCID = @ATUAL;

	INSERT INTO sankhya.TSICID 
	(CODCID, NOMECID, DESCRICAOCORREIO, 
	CODMUNFIS, AD_SUSPEITADEFRAUDE, DTALTER, 
	TIPOFRETE, QTDDIASSUB, QTDSUB, 
	TEMSUBSTITNFSE, CODREG, UF)
	VALUES 
	(@INI, @NOMECID, @DESCRICAOCORREIO, 
	@CODMUNFIS, @SUSPEITADEFRAUDE, @DTALTER, 
	'C', 0, 0, 
	'N', 0, @UF);
	
	UPDATE sankhya.TCCEMP SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TFPFUN SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TFPPCA SET CODCID = @INI WHERE CODBAI = @ATUAL;
	UPDATE sankhya.TGAENT SET CODCID = @INI WHERE CODBAI = @ATUAL;
	UPDATE sankhya.TGFCPL SET CODCIDENTREGA = @INI WHERE CODCIDENTREGA = @ATUAL;
	UPDATE sankhya.TGFCPL SET CODCIDRECEB = @INI WHERE CODCIDRECEB = @ATUAL;
	UPDATE sankhya.TGFCPL SET CODCIDTRAB = @INI WHERE CODCIDTRAB = @ATUAL;
	UPDATE sankhya.TGFCTT SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TGFPAR SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TGFSIT SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TSIAGE SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TSICEP SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.TSIEMP SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.AD_PEDIDOVTEXSCREENVIOMOVIMENTO SET CODCID = @INI WHERE CODCID = @ATUAL;
	UPDATE sankhya.AD_PEDIDOVTEXSCMOVIMENTACAO SET CODCID = @INI WHERE CODCID = @ATUAL;

	DELETE FROM sankhya.TSICID WHERE CODCID = @ATUAL;

	SET @INI = @INI + 1;
END;

ALTER TABLE sankhya.TGFPAR ENABLE TRIGGER ALL;
ALTER INDEX [AK_NOMECID_TSICID] ON sankhya.TSICID REBUILD;
ALTER INDEX [IX_CODMUNFIS_TSICID] ON sankhya.TSICID REBUILD;
ALTER TABLE sankhya.TSICID WITH CHECK CHECK CONSTRAINT ALL;