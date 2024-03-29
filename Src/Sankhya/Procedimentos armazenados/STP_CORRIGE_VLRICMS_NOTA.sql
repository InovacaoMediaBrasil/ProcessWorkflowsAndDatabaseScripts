USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_VLRICMS_NOTA]    Script Date: 27/03/2017 09:48:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Rafael Turra Silva
-- Create date: 2016-09-15
-- Description:	Corrige o valor de ICMS da CAB
-- =============================================
ALTER PROCEDURE [sankhya].[STP_CORRIGE_VLRICMS_NOTA] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @PARAM_VLRICMS FLOAT,
       @FIELD_NUNOTA INT,
       @VLRICMS FLOAT,
	   @VALOR FLOAT
BEGIN
       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.
	   SET @PARAM_VLRICMS = SANKHYA.ACT_DEC_PARAM(@P_IDSESSAO, 'VLRICMS')

	   /* SE O NÚMERO DE LINHAS SELECIONADAS FOR MAIOR DO QUE 1 NÃO REALIZARÁ A OPERAÇÃO */
	   IF @P_QTDLINHAS > 1 
	   		RAISERROR('Selecione uma nota por vez',16,1);
		
       /* obtendo o NUNOTA */
           SET @FIELD_NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, 1, 'NUNOTA')

	   /* VERIFICA SE O CÓDIGO DA OPERAÇÃO É 505 PARA ATUALIZAR O ICMS */
		IF NOT EXISTS (SELECT 1 FROM sankhya.TGFCAB WHERE NUNOTA = @FIELD_NUNOTA AND CODTIPOPER = 505)
				RAISERROR('Selecione uma nota de expedição',16,1);
     
	  /* CASO O VALOR DE ICMS ESTEJA ERRADO, FAÇA AS ALTERAÇÕES */
	 	UPDATE sankhya.TGFCAB SET VLRICMS = @PARAM_VLRICMS WHERE NUNOTA = @FIELD_NUNOTA;
		
		SET @P_MENSAGEM = 'Valor de ICMS ' + cast(@PARAM_VLRICMS AS VARCHAR) + ' corrigido com sucesso na nota. Favor confirme a nota.'
			         
END