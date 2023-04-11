USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_DLT_TGFVCS_AD_MULTILOJA]    Script Date: 13/12/2016 22:12:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 19/08/2016
-- Description:	Atualiza produto na tabela AD_MULTILOJA assim que uma venda casada (sugestão/acessório) for adicionada, removida ou alterada
-- =============================================
ALTER TRIGGER [sankhya].[TRG_INC_DLT_TGFVCS_AD_MULTILOJA] 
   ON  [sankhya].[TGFVCS]
   AFTER INSERT, UPDATE, DELETE
AS 
DECLARE
	@CODPROD INT
BEGIN
	SET NOCOUNT ON;
	SELECT @CODPROD = ISNULL(I.CODORIG, D.CODORIG)
	FROM INSERTED AS I 
	FULL OUTER JOIN DELETED AS D 
	ON I.CODORIG = D.CODORIG;
	UPDATE AD_MULTILOJA SET ALTPRODUTO = 'S', DTMODIF = GETDATE() WHERE CODPROD =  @CODPROD;	
END
