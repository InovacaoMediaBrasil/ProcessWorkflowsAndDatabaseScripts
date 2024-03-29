USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_AD_PRODUTOLOJA_SINCRONIZACAO]    Script Date: 27/04/2018 12:38:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	27/04/2018
	Description:	Mantém as lojas 0 e 1 sincronizadas (ou ativo ou inativo nas duas, para que não tenha problema nos canais de vendas)
	============================================= */
ALTER TRIGGER [sankhya].[TRG_UPD_AD_PRODUTOLOJA_SINCRONIZACAO]
   ON  [sankhya].[AD_PRODUTOLOJA] 
   AFTER UPDATE
AS 
DECLARE
@CODPROD		INT,
@CODLOJA_INS	INT,
@ATIVO_INS		CHAR(1),
@ATIVO_WMW		CHAR(1),
@ATIVO_EC		CHAR(1),
@SOLICITANTE	CHAR(30),
@CODLOJAATIVAR	INT,
@NOMELOJA		VARCHAR(50),
@ERROR			VARCHAR(255);
BEGIN
	SET NOCOUNT ON;
	
	IF NOT UPDATE(ATIVO)
		RETURN;

	-- OBTENDO AS INFORMAÇÕES
	SELECT	@CODPROD =		CODPROD,
			@CODLOJA_INS =	CODLOJA, 
			@ATIVO_INS =	ATIVO 
	FROM INSERTED;

	/*
	 * Verifica se a ativação é em uma loja valida para trigger (0 e 1)
	 */
	IF @CODLOJA_INS NOT IN (0, 1)
		RETURN;

	/*
	 * Determina qual loja deve ser ativada e obtém o nome da loja na tabela AD_LOJA
	 */

	SET @CODLOJAATIVAR = (CASE WHEN @CODLOJA_INS = 0 THEN 1 ELSE 0 END);
	SELECT @NOMELOJA = NOMELOJA 
	FROM AD_LOJA WITH (NOLOCK) 
	WHERE CODLOJA = @CODLOJAATIVAR;


	IF @ATIVO_INS = 'S'
	BEGIN TRY
		UPDATE AD_PRODUTOLOJA
		SET ATIVO = 'S'
		WHERE CODLOJA = @CODLOJAATIVAR
		AND CODPROD = @CODPROD;
	END TRY
	BEGIN CATCH
		SELECT @ERROR = ERROR_MESSAGE();
		RAISERROR('Não foi possível liberar o produto %i para os dois canais de vendas.<br />Favor verificar o canal de vendas  %i - %s.<br /><br />Erro:<br /> %s', 16, 1, @CODPROD, @CODLOJAATIVAR, @NOMELOJA, @ERROR);
		SELECT @SOLICITANTE = UPPER(program_name)
		FROM MASTER.DBO.SYSPROCESSES
		WHERE SPID = @@SPID;

		IF	@SOLICITANTE LIKE 'MICROSOFT%'
		OR	@SOLICITANTE = 'MS SQLEM' 
		OR 	@SOLICITANTE = 'MS SQL QUERY ANALYZER' 
		OR	@SOLICITANTE LIKE 'TOAD%'
			ROLLBACK  TRANSACTION;
	END CATCH

	ELSE
		UPDATE AD_PRODUTOLOJA
		SET ATIVO = 'N'
		WHERE CODLOJA = @CODLOJAATIVAR
		AND CODPROD = @CODPROD;
END