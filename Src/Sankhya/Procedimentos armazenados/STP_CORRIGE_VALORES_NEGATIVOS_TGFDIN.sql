USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN]    Script Date: 20/03/2018 15:59:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2016-12-03
	Description:	Corrige o valores negativos na TGFDIN

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-17
	Description:	STP extraida para STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN_INTERNAL para permitir correção manual e/ou via IS.
					Permite a correção de várias notas (WHILE)
	============================================= */
ALTER PROCEDURE [sankhya].[STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_NUNOTA INT,
	   @CURRENT INT
BEGIN
	/*
	 * Inicia contador do loop com valor 1
	 */
	SET @CURRENT = 1;
	
	/*
	 * Loop para cada nota selecionada na grade
	 */

	WHILE @CURRENT <= @P_QTDLINHAS
	BEGIN
		/*
		 * Obtém o NUNOTA atual;
		 */

		SET @FIELD_NUNOTA = sankhya.ACT_INT_FIELD(@P_IDSESSAO, @CURRENT, 'NUNOTA');

		/*
		 * Executa a procedure de mesmo nome, com final INTERNAL para corrigir a nota.
		 */

		EXEC sankhya.STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN_INTERNAL @NUNOTA = @FIELD_NUNOTA, @CODUSU= @P_CODUSU;
	
		/*
		 * Continua o loop.	
		 */
		SET @CURRENT = @CURRENT + 1;
	END
	
	/*
	 * Informa ao usuário que X notas foram corrigidas.
	 */
	SET @P_MENSAGEM = 'Impostos negativos corrigidos em ' + CAST(@P_QTDLINHAS AS VARCHAR) + ' notas';	
END