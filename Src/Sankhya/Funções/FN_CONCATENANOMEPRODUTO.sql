USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[FN_CONCATENANOMEPRODUTO]    Script Date: 04/09/2018 13:15:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		RAFAEL TURRA SILVA
-- Create date: 2016-09-30
-- Description:	Concatena o nome do produto, descrição e marca
-- =============================================
ALTER FUNCTION [sankhya].[FN_CONCATENANOMEPRODUTO] (@CODPROD INT)
RETURNS VARCHAR(MAX)
AS BEGIN
	DECLARE @NOME VARCHAR(MAX);
	SELECT @NOME = RTRIM(LTRIM(RTRIM(LTRIM(PRO.DESCRPROD)) + ' ' + RTRIM(LTRIM(ISNULL(PRO.COMPLDESC, ''))))) 
	FROM  sankhya.TGFPRO AS PRO WITH(NOLOCK) WHERE CODPROD = @CODPROD;
	RETURN @NOME;
END
