USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFCAB_BONIFICADO_INVALIDO]    Script Date: 06/04/2017 10:53:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2017-02-21
-- Description:	Valida a criação de pedido bonificado no sistema. Não permite a criação de pedido bonificado se:
--				- Não existe um pedido original (AD_PEDORIGINAL) informado e ele é válido
--				- O parceiro do bonificado é diferente do parceiro do pedido original
-- =============================================
ALTER TRIGGER [sankhya].[TRG_UPD_TGFCAB_BONIFICADO_INVALIDO]
   ON  [sankhya].[TGFCAB] 
   AFTER UPDATE
AS 
DECLARE
@PEDORIGINAL INT,
@CODPARC INT,
@CODTIPOPER INT,
@SOLICITANTE CHAR(30)
BEGIN
	SET NOCOUNT ON;
	
	SELECT @PEDORIGINAL = I.AD_PEDORIGINAL, @CODPARC = I.CODPARC, @CODTIPOPER = I.CODTIPOPER
	FROM INSERTED I
	
	IF @CODTIPOPER = 504
	AND (@PEDORIGINAL IS NULL 
	OR @PEDORIGINAL = 0 
	OR NOT EXISTS (
		SELECT 1 
		FROM sankhya.TGFCAB AS C
		WHERE C.AD_PEDORIGINAL = @PEDORIGINAL
		AND CODPARC = @CODPARC
		AND C.CODTIPOPER IN (500, 501, 502, 503, 515)
	))
	BEGIN
		SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
		RAISERROR('Pedido bonificado só é permitido para um pedido original válido e para o mesmo parceiro.', 16, 1);	
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END	
END
