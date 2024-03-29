USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[FN_CALCULA_VALOR_BRINDES]    Script Date: 15/03/2017 17:01:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		RODRIGO LACALENDOLA
-- Create date: 2016-05-27
-- Description:	CALCULO DO VALOR TOTAL DE BRINDES DE UM KIT
-- =============================================
ALTER FUNCTION [sankhya].[FN_CALCULA_VALOR_BRINDES]
(
	@CODPROD INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @VLRBRINDE DECIMAL(10,2)

	SET @VLRBRINDE = (SELECT SUM(AD_VLRVENDA)
	FROM sankhya.TGFICP	
	WHERE CODPROD = @CODPROD
	AND AD_BRINDE = 'S')

	RETURN @VLRBRINDE

END
