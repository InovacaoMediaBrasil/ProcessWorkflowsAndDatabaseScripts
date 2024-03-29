USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA_EAN]    Script Date: 27/04/2018 11:57:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	18/05/2017
	Description:	Verifica se o EAN do produto é válido. Caso contrário, cancela a operação.
	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA_EAN]
   ON  [sankhya].[AD_PRODUTOLOJA] 
   AFTER INSERT, UPDATE
AS 
DECLARE
@CODPROD INT,
@ATIVO CHAR(1),
@SITUACAO CHAR(4),
@ERRMSG VARCHAR(100),
@SOLICITANTE CHAR(30)

BEGIN
	SET NOCOUNT ON;
	
	IF NOT UPDATE(ATIVO)
		RETURN;

	/* OBTEM OS DADOS DA ALTERAÇÃO/INCLUSÃO */
	SELECT	@CODPROD =		I.CODPROD, 
			@ATIVO =		I.ATIVO,
			@SITUACAO =		CAST(sankhya.FN_VERIFICA_EAN(I.CODPROD)	AS CHAR(4))		
	FROM INSERTED AS I;


	/* CASO NÃO ESTEJA ATIVANDO OU O EAN ESTEJA CORRETO ENCERRA*/
	IF @ATIVO != 'S' 
	OR @SITUACAO NOT LIKE '%ERRO%'
		RETURN;

	SET @ERRMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não pode ser liberado para venda porque o EAN do produto é inválido';
	EXEC SANKHYA.SNK_ERROR @ERRMSG;
	
	SELECT @SOLICITANTE = program_name
	FROM MASTER.DBO.SYSPROCESSES
	WHERE SPID = @@SPID;

	IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
	OR @SOLICITANTE = 'MS SQLEM'
	OR @SOLICITANTE = 'MS SQL QUERY ANALYZER'
	OR UPPER(@SOLICITANTE) LIKE 'TOAD%'
		ROLLBACK  TRANSACTION;
END