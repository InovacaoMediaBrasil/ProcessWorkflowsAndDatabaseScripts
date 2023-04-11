USE [SANKHYA_PRODUCAO]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2016-01-06
-- Description:	Função que remove acentuação e caracteres proibidos para geração de NF-e
-- =============================================

CREATE FUNCTION [sankhya].[FN_REMOVER_ACENTUACAO] ( @TEXTO VARCHAR(MAX) ) 
RETURNS VARCHAR(MAX) 
AS
BEGIN
DECLARE 
@TEXTO_FORMATADO VARCHAR(MAX);
	
	-- O trecho abaixo possibilita que caracteres como "º" ou "ª"
	-- sejam convertidos para "o" ou "a", respectivamente
	SET @TEXTO_FORMATADO = UPPER(@TEXTO) COLLATE sql_latin1_general_cp1250_ci_as;
	
	-- O trecho abaixo remove acentos e outros caracteres especiais, 
	-- substituindo os mesmos por letras normais
	SET @TEXTO_FORMATADO = @TEXTO_FORMATADO COLLATE sql_latin1_general_cp1251_ci_as;
	RETURN @TEXTO_FORMATADO;
END