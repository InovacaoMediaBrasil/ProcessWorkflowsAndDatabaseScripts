USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_IMP_NOTAVENDA]    Script Date: 27/03/2017 08:44:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:		Décio Bento, Rodrigo Lacalendola
	Create date: 2014-07-15
	Description:	Adição de procedure para funcionamento dentro da aba "ações" no Portal de Vendas do Sankhya (Correção de impostos, valores e frete)

	=============================================*/

ALTER PROCEDURE [sankhya].[STP_IMP_NOTAVENDA] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @NUNOTA INT,
	   @CODTIPOPER INT,
	   @STATUSNFE CHAR(1),
	   @RETORNO INT,
	   @SOLICITANTE CHAR(30)
BEGIN
--		    /* Obtem o NUNOTA da nota selecionada no portal */
--			SET @NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, 1, 'NUNOTA')
			
--			/* Seleciona tipo de operação e status da NFe */
--			SELECT @CODTIPOPER = CODTIPOPER, @STATUSNFE = STATUSNFE FROM sankhya.TGFCAB WHERE NUNOTA = @NUNOTA

--			/* Verifica se é da top 550 e está aguardando correção */
--			IF (@CODTIPOPER = 550 AND (@STATUSNFE in ('R','V') OR @STATUSNFE IS NULL))
--			BEGIN

--				   /* Executa a procedure para correção de estoque */
--					EXEC @RETORNO = dbo.STP_CORRETORNFESEMFRETECURSOR @NUNOTA

--					/* Mensagem de retorno de acordo com o resultado da execução da procedure */
--					IF @RETORNO = 0
--						SET @P_MENSAGEM = 'Os valores, frete e impostos da nota foram corrigidos. Você já pode clicar em "Gerar lote" para aprovação da nota na SEFAZ.'
--					ELSE
--						SET @P_MENSAGEM = 'Erro: não foi possível executar a ação - problema na execução da procedure STP_CORRETORNFESEMFRETE'
						
--			END 
--			ELSE
--			BEGIN
--				SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
--				RAISERROR('Somente são permitidas correções de notas da TOP 550 e que estão aguardando correção.', 16, 1);	
--				IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
--					ROLLBACK TRANSACTION;
--			END		

-- COMENTEI PARA ARRUMAR AS NOTAS -- RAFAEL TURRA 13-07-2016
		  
SET @RETORNO = 0
END
