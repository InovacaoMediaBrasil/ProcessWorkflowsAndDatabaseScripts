USE [SANKHYA_PRODUCAO]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Change date:	2017-08-24
	Description:	Após a inclusão, alteração ou delete nesta tabela, é marcado na AD_MULTILOJA uma alteração de estoque.
	 ============================================= */
CREATE TRIGGER [sankhya].[TRG_INC_UPD_DLT_AD_MULTILOJA] 
   ON  [sankhya].[AD_ESTHIST]
   AFTER INSERT,UPDATE,DELETE
AS 
DECLARE
@CODPROD INT
BEGIN
	SET NOCOUNT ON;	

	/* Obtem os dados do item inserido ou deletado */
	SELECT @CODPROD = CODPROD FROM inserted

	IF @CODPROD IS NULL
		SELECT @CODPROD = CODPROD FROM deleted


	/* Atualiza o estoque tanto do item quanto dos kits que este item pertence */
	UPDATE M SET ALTESTOQUE = 'S' FROM sankhya.AD_MULTILOJA M
	LEFT JOIN sankhya.TGFICP ICP ON ICP.CODPROD = M.CODPROD
	WHERE M.CODPROD = @CODPROD OR ICP.CODMATPRIMA = @CODPROD
	

END