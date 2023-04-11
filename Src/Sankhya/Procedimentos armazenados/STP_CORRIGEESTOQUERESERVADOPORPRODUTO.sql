-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 25/11/2013
-- Description:	Efetua o cálculo de quantidade Reservada para determinado produto
-- =============================================
CREATE PROCEDURE sankhya.STP_CORRIGEESTOQUERESERVADOPORPRODUTO
	@CODPROD INT = 0
AS
BEGIN
DECLARE @RESERVADO FLOAT;
	SET NOCOUNT ON;

	SELECT @RESERVADO = ISNULL(SUM(QTDNEG), 0) 
	FROM sankhya.TGFITE AS I 
	INNER JOIN sankhya.TGFCAB AS C ON (C.NUNOTA = I.NUNOTA) 
	INNER JOIN sankhya.TGFTOP AS T ON (T.CODTIPOPER = C.CODTIPOPER AND T.DHALTER = C.DHTIPOPER)
	WHERE I.CODPROD = @CODPROD 
	AND C.PENDENTE = 'S' 
	AND C.DTNEG >= DATEADD(DAY, -90, GETDATE())
	AND T.ATUALEST = 'R';
	
	UPDATE sankhya.TGFEST SET RESERVADO = @RESERVADO WHERE CODPROD = @CODPROD;
	UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTESTOQUE = 'S' WHERE CODPROD = @CODPROD;	
	UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTESTOQUE = 'S' WHERE CODPROD IN (SELECT CODPROD FROM TGFICP WHERE CODMATPRIMA = @CODPROD)
END
GO