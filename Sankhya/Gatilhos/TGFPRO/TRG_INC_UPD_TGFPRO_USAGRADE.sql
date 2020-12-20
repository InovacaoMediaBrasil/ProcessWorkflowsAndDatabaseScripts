USE [SANKHYA_PRODUCAO]
GO

/****** Object:  Trigger [sankhya].[TRG_INC_UPD_TGFPRO_USAGRADE]    Script Date: 02/09/2014 17:04:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Decio Bento Junior
-- Create date: 2014-08-20
-- Change date: 2016-12-13 (Guilherme Branco Stracini)
-- Description:	Valida produtos Usa Grade (valida código, produto pai, limitação de irmãoes - 50 SKUs por produto)
-- =============================================
ALTER TRIGGER [sankhya].[TRG_INC_UPD_TGFPRO_USAGRADE] 
   ON  [sankhya].[TGFPRO]
	FOR INSERT, UPDATE
AS 
DECLARE 
@CODPROD INT,
@CODPRODPAI INT,
@CODPRODPAIDOPAI INT,
@IRMAOS INT,
@USAGRADE CHAR(1),
@USAGRADEPAI CHAR(1),
@NOMEPRODUTO VARCHAR(40),
@NOMEPRODUTOPAI VARCHAR(40),
@SOLICITANTE CHAR(30),
@MENSAGEM VARCHAR(150),
@ERRO CHAR(1)
BEGIN

	SET NOCOUNT ON;

	SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
	SELECT @CODPROD = CODPROD, @CODPRODPAI = AD_CODPAI, @USAGRADE = AD_USAGRADE, @NOMEPRODUTO = DESCRPROD FROM INSERTED;
	SELECT @CODPRODPAIDOPAI = AD_CODPAI, @USAGRADEPAI = AD_USAGRADE, @NOMEPRODUTOPAI = DESCRPROD FROM sankhya.TGFPRO WHERE CODPROD = @CODPRODPAI;
	SELECT @IRMAOS = COUNT(1) FROM sankhya.TGFPRO WHERE AD_CODPAI = @CODPRODPAI AND ATIVO = 'S';
	
	IF @CODPRODPAI IS NOT NULL						
	BEGIN
		IF (@CODPROD < @CODPRODPAI)
		BEGIN
			SET @ERRO = 'S';
			RAISERROR('O código do produto pai deve ser menor que o código deste Produto', 16, 1);
		END

		IF (@USAGRADE <> 'S')
		BEGIN
			SET @ERRO = 'S';
			RAISERROR('Este produto não é Usa Grade e possui um produto pai associado', 16, 1);			
		END

		IF (@USAGRADEPAI <> 'S' AND @CODPROD <> @CODPRODPAI)
		BEGIN
			SET @ERRO = 'S';
			RAISERROR('Produto pai não é Usa Grade', 16, 1);
		END		
		
		IF (@CODPRODPAI <> @CODPRODPAIDOPAI)
		BEGIN
			SET @ERRO = 'S';		
			RAISERROR('Produto pai %i possui outro produto pai: %i', 16, 1, @CODPRODPAI, @CODPRODPAIDOPAI);
		END

		IF (@CODPRODPAIDOPAI IS NULL) 
		BEGIN
			SET @ERRO = 'S';
			RAISERROR('Produto pai %i não está associado a si mesmo', 16, 1, @CODPRODPAI);
		END

		IF (@NOMEPRODUTO <> @NOMEPRODUTOPAI)
		BEGIN
			SET @ERRO = 'S';
			RAISERROR('O nome do produto pai %i é diferente do nome deste produto', 16, 1, @CODPRODPAI);
		END
	END

	IF(@IRMAOS > 50)
	BEGIN
		SET @ERRO = 'S';
		RAISERROR('Já existem 50 produtos associados a esta grade',16,1);
	END
	
	IF (@USAGRADE = 'S' AND @CODPRODPAI IS NULL)
	BEGIN
		SET @ERRO = 'S';
		RAISERROR('Produto é Usa Grade porém não foi informado o produto pai', 16, 1);
	END

	IF @ERRO <> 'N' AND ((UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER'))
		ROLLBACK TRANSACTION;
END