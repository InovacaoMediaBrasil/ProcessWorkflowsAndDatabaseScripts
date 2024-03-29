USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_DEV_COMPRA_ST_E_IPI]    Script Date: 27/03/2017 11:18:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_CORRIGE_DEV_COMPRA_ST_E_IPI] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @NUNOTA INT,
	   @STATUSNFE VARCHAR(1)
   
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

	   /* obtendo o NUNOTA */

	   SET @NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, 1, 'NUNOTA')

	  
	  
	  /* OBTENDO O STATUS ATUAL DA NFE */
		SELECT @STATUSNFE=STATUSNFE FROM sankhya.TGFCAB WHERE NUNOTA = @NUNOTA


		/* CASO A NOTA JÁ ESTEJA APROVADA, RETORNA;*/
	   IF (@STATUSNFE = 'A')
	   BEGIN
			SET @P_MENSAGEM = 'NFe já aprovada. Rotina não executada.'
			RETURN
	   END

	   /* CASO AINDA NAÕ ESTEJA APROVADA, FAÇA AS ALTERAÇÕES: */

	   ELSE
	   BEGIN

	   		---- 2. alterar o CSTIPI

		    update sankhya.TGFITE SET CSTIPI = 50 WHERE VLRIPI > 0 AND NUNOTA = @NUNOTA 

			---- 3. alterar o CST

			update sankhya.TGFITE SET CODTRIB = 10 WHERE VLRSUBST > 0 AND NUNOTA = @NUNOTA 


			SET @P_MENSAGEM = 'Configuração do IPI e Substituição corrigidas. Favor gerar o lote da NFe.'

	   END
	   




END
