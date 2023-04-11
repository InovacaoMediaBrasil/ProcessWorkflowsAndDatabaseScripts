-- ================================================
-- Template generated from Template Explorer using:
-- Create Trigger (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- See additional Create Trigger templates for more
-- examples of different Trigger statements.
--
-- This block of comments will not be included in
-- the definition of the function.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 30/09/2013
-- Description:	Atualiza AD_MULTILOJA para efetuar recalculo de estoque
-- =============================================
CREATE TRIGGER sankhya.TRG_INC_UPD_DLT_TGFCAB_AD_MULTILOJA 
   ON  sankhya.TGFCAB 
   AFTER INSERT,UPDATE,DELETE
AS 
DECLARE 
	@NUNOTA INT
BEGIN
	SET NOCOUNT ON;   
    SELECT @NUNOTA = ISNULL(I.NUNOTA,D.NUNOTA) 
	FROM INSERTED AS I FULL 
	OUTER JOIN DELETED AS D 
	ON I.NUNOTA = D.NUNOTA;
	
	UPDATE AD_MULTILOJA 
	SET DTMODIF = GETDATE(), ALTESTOQUE = 'S', ESTOQUE = sankhya.FN_ESTOQUE_INOVACAO(CODPROD)
	WHERE CODPROD IN (
		SELECT I.CODPROD 
		FROM TGFITE AS I 
		WHERE I.NUNOTA = @NUNOTA 
		AND EXISTS(
			SELECT 1 
			FROM TGFPRO AS P 
			WHERE P.CODPROD = I.CODPROD 
			AND (P.AD_PESTNEG = 'N' OR P.AD_PESTNEG IS NULL)
		)
	);
	
	UPDATE AD_MULTILOJA 
	SET DTMODIF = GETDATE(), ALTESTOQUE = 'S', ESTOQUE = sankhya.FN_ESTOQUE_INOVACAO(CODPROD)
	WHERE CODPROD IN (
		SELECT M.CODPROD 
		FROM TGFICP AS M
		WHERE M.CODMATPRIMA IN (
			SELECT I.CODPROD 
			FROM TGFITE AS I 
			WHERE I.NUNOTA = @NUNOTA 			
		)
		AND EXISTS(
			SELECT 1 
			FROM TGFPRO AS P 
			WHERE P.CODPROD = M.CODPROD 
			AND (P.AD_PESTNEG = 'N' OR P.AD_PESTNEG IS NULL)
		)
	)
END
GO
