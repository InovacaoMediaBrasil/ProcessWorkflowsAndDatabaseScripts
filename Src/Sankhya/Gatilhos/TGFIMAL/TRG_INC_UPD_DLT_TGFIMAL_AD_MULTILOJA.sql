USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_DLT_TGFIMAL_AD_MULTILOJA]    Script Date: 13/12/2016 22:14:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 19/08/2016
-- Description:	Atualiza produto na tabela AD_MULTILOJA assim que uma imagem alternativa for adicionada, removida ou alterada
-- =============================================
ALTER TRIGGER [sankhya].[TRG_INC_DLT_TGFIMAL_AD_MULTILOJA] 
   ON  [sankhya].[TGFIMAL]
   AFTER INSERT, UPDATE, DELETE
AS 
DECLARE
	@CODPROD INT
BEGIN
	SET NOCOUNT ON;
	SELECT @CODPROD = ISNULL(I.CODPROD, D.CODPROD)
	FROM INSERTED AS I 
	FULL OUTER JOIN DELETED AS D 
	ON I.CODPROD = D.CODPROD;
	UPDATE AD_MULTILOJA SET ALTPRODUTO = 'S', DTMODIF = GETDATE() WHERE CODPROD =  @CODPROD;	
END