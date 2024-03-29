USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_DLT_AD_PRODUTOLOJA]    Script Date: 03/10/2018 19:46:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 27/09/2013
-- Description:	Atualiza coluna DTALTER na AD_MULTILOJA quando um produto for removido de determinada Loja
-- =============================================
ALTER TRIGGER [sankhya].[TRG_DLT_AD_PRODUTOLOJA]
   ON  [sankhya].[AD_PRODUTOLOJA] 
   AFTER DELETE
AS 
DECLARE
@SOLICITANTE CHAR(30)
BEGIN
	SET NOCOUNT ON;
	BEGIN
		SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
		RAISERROR('Não é permitido remover o Canal de Vendas do produto por causa da Integração. Inative-o para que o produto não esteja mais disponível nele.', 16, 1);	
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END	
END
