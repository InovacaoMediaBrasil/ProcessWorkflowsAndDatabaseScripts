USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_TGFCAB_BAIXA_TOP503]    Script Date: 30/03/2017 14:53:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Rafael Turra Silva
-- Create date: 2017-03-17
-- Description:	Realiza a baixa financeira de pedido de professor. Liberado para o financeiro
-- =============================================
ALTER PROCEDURE [sankhya].[STP_TGFCAB_BAIXA_TOP503] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @NUNOTA INT,
	   @ORIGINAL INT,
	   @STATUSPGTO CHAR(1),
	   @TIPVENDA INT,
	   @CODTIPOPER INT
   
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

        /* Obtem o NUNOTA da nota selecionada no portal */
		SET @NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, 1, 'NUNOTA')

        SELECT	@ORIGINAL = AD_PEDORIGINAL,
				@STATUSPGTO = AD_STATUSPGTO,
				@TIPVENDA = CODTIPVENDA,
				@CODTIPOPER = CODTIPOPER
		FROM	sankhya.TGFCAB CAB
		WHERE	NUNOTA = @NUNOTA

	  	/* VERIFICA O STATUS DE PAGAMENTO */
		IF  @STATUSPGTO = 'E'
			RAISERROR('Pagamento já está como efetuado',16,1)
		IF @TIPVENDA != 49 OR @CODTIPOPER != 503
			RAISERROR('Tipo de negociação diferente de bonificado.',16,1)
	
		UPDATE sankhya.TGFCAB SET AD_STATUSPGTO = 'E' WHERE AD_PEDORIGINAL = @ORIGINAL

		SET @P_MENSAGEM = 'O status do pagamento foi alterado com sucesso.'
		
	         
END


