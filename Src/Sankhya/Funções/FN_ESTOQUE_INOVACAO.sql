USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[FN_ESTOQUE_INOVACAO]    Script Date: 14/08/2018 13:07:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2015-09-01
	Description:	Função que efetua o cálculo de estoque para KIT e para produto e faz as devidas validações

	Author:			Rodrigo Lacalendola
	Change date:	2016-11-23
	Description:	Retirado tabelas temporárias

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-10
	Description:	Melhoradas as queries, adicionado comentários.
					Verificação se é KIT não mais pelo CODVOL da PRO e sim se existe na TGFICP (o que garante que é um KIT com componentes)]

	Author:			Guilherme Branco Stracini
	Change date:	2018-08-14
	Description:	Colocado o código de empresa 1 nas ligações com a TGFEST
	============================================= */
ALTER FUNCTION [sankhya].[FN_ESTOQUE_INOVACAO] (@CODPROD INT) RETURNS FLOAT
AS BEGIN
	DECLARE @SALDO FLOAT;

	/*
	 * Se existir na TGFICP na coluna CODPROD algum código com o mesmo código passado é um KIT,
	 * neste caso então faz a conta de quanto tem de cada componente e utiliza o menor disponível como saldo
	 */

	IF EXISTS (SELECT 1 FROM TGFICP WITH(NOLOCK) WHERE CODPROD = @CODPROD) 
		SELECT @SALDO = MIN(CASE WHEN AD_PESTNEG = 'S' THEN 1000 ELSE FLOOR((ISNULL(EST.ESTOQUE,0)-ISNULL(EST.RESERVADO,0))/QTDMISTURA) END)
		FROM TGFICP AS ICP WITH (NOLOCK)
		INNER JOIN TGFPRO AS PRO WITH (NOLOCK)
		ON PRO.CODPROD = ICP.CODMATPRIMA
		LEFT JOIN TGFEST AS EST WITH (NOLOCK)
		ON EST.CODPROD = ICP.CODMATPRIMA AND EST.CODEMP = 1
		WHERE ICP.CODPROD = @CODPROD;

	/*
	 * Caso não seja KIT verifica o saldo diretamente na TGFEST
	 */

	ELSE 
		SELECT @SALDO = (CASE WHEN AD_PESTNEG = 'S' THEN 1000 ELSE ISNULL(ESTOQUE-RESERVADO, 0) END)
		FROM TGFPRO AS PRO WITH (NOLOCK)
		LEFT JOIN TGFEST AS EST WITH (NOLOCK)
		ON EST.CODPROD = PRO.CODPROD AND EST.CODEMP = 1
		WHERE PRO.CODPROD = @CODPROD;
	
	/*
	 * Retorna a variavel saldo, se for nula retorna 0
	 */
	RETURN ISNULL(@SALDO, 0);
END
