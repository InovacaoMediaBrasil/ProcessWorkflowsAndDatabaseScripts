USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_ICMS_INTERESTADUAL]    Script Date: 20/03/2018 16:20:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2016-01-09
	Description:	Corrige valor total do diferencial de aliquota com base na tabela TGFDIN

	Author:			Guilherme Branco Stracini
	Change date:	2018-03-30
	Description:	Chama o procedimento STP_CORRIGE_ICMS_INTERESTADUAL_INTERNAL para fazer o processo nota a nota.
					A correção é feita por outro procedimento para permitir que a Integração também utilize ele, sem precisar estar no Sankhya-W
	============================================= */

ALTER PROCEDURE [sankhya].[STP_CORRIGE_ICMS_INTERESTADUAL] (
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

		EXEC sankhya.STP_CORRIGE_ICMS_INTERESTADUAL_INTERNAL @NUNOTA = @FIELD_NUNOTA, @CODUSU= @P_CODUSU;
	
		/*
		 * Continua o loop.	
		 */
		SET @CURRENT = @CURRENT + 1;
	END
	
	/*
	 * Informa ao usuário que X notas foram corrigidas.
	 */
	SET @P_MENSAGEM = 'ICMS interestadual corrigidos em ' + CAST(@P_QTDLINHAS AS VARCHAR) + ' notas';
END