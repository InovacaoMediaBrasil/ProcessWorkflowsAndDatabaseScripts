USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_NOTA_DEVOLUCAO_VENDA]    Script Date: 19/05/2017 09:02:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_CORRIGE_NOTA_DEVOLUCAO_VENDA] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_NUNOTA INT,
       @I INT
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.


       SET @I = 1 -- A variável "I" representa o registro corrente.
       WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       BEGIN
			-- Para obter o valor dos campos utilize uma das seguintes funções:
			--     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
			--     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
			--     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
			--     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
			-- Estas funções recebem 3 argumentos:
			--     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
			--     NÚMERO DA LINHA - Relativo a qual linha selecionada.
			--     NOME DO CAMPO - Determina qual campo deve ser obtido.
			SET @FIELD_NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'NUNOTA')

			IF NOT EXISTS (SELECT 1 FROM TGFCAB WITH (NOLOCK) WHERE NUNOTA = @FIELD_NUNOTA AND CODTIPOPER = 600)
			BEGIN
				RAISERROR('Selecione uma nota da TOP 600 - Devolução. A nota %i não é da TOP 600.', 16, 1, @FIELD_NUNOTA);
				RETURN;
			END

			/* Passos para corrigir a nota de devolução de venda: */
			/* 1. colocar o valor dos produtos kits igual a somatória do itens; */
			UPDATE ITE SET VLRUNIT = dbo.VALOR_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA), VLRTOT = dbo.VALOR_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA)*QTDNEG, VLRDESC = dbo.VALOR_DO_DESCONTO_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA)
			FROM sankhya.TGFITE ITE INNER JOIN sankhya.TGFCAB CAB ON CAB.NUNOTA = ITE.NUNOTA WHERE ITE.USOPROD = 'R' AND CODVOL = 'KT' and ite.nunota = @FIELD_NUNOTA;
		
			/* 2. retirar o frete* e alterar o VLRNOTA sendo a somatória dos itens; */
			UPDATE sankhya.TGFCAB
			SET VLRNOTA = sankhya.FN_PRECO_DOS_ITENS_DO_PEDIDO(NUNOTA), VLRFRETE = 0
			WHERE nunota = @FIELD_NUNOTA;

			/* 3. alterar o valor na DIN para ficar igual ao valor da ITE; */
			--/* resolvendo cofins */
			UPDATE
			DIN SET BASE = (VLRTOT-VLRDESC), BASERED = (VLRTOT-VLRDESC), ALIQUOTA=3, VALOR = round((VLRTOT-VLRDESC)*(3/100),2)
			FROM sankhya.TGFDIN DIN INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND CODIMP = 7
			WHERE DIN.NUNOTA = @FIELD_NUNOTA;

			/* resolvendo pis */
			UPDATE
			DIN SET BASE = (VLRTOT-VLRDESC), BASERED = (VLRTOT-VLRDESC), ALIQUOTA=0.65, VALOR = round((VLRTOT-VLRDESC)*(0.65/100),2)
			FROM sankhya.TGFDIN DIN INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND CODIMP = 6
			WHERE DIN.NUNOTA = @FIELD_NUNOTA;

			/* 4. quando for kit, zerar o pis e cofins; */
			/* resolvendo o valor do pis e cofins para kits */
			UPDATE
			DIN SET VALOR = 0 FROM sankhya.TGFDIN DIN INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND USOPROD = 'R' AND CODVOL = 'KT'
			WHERE DIN.NUNOTA = @FIELD_NUNOTA AND CODIMP IN (6,7);

			/* 5. quando for reenvio, corrige os valores para ficar tudo zerado */
			UPDATE DIN SET VLRCRED=0,VLRDIFALDEST = 0,VLRDIFALREM=0,VLRFCP=0, PERCFCP=0, PERCPARTDIFAL=0, ALIQINTDEST=0 FROM sankhya.TGFDIN DIN
			INNER JOIN sankhya.TGFCAB CAB ON CAB.NUNOTA = DIN.NUNOTA
			WHERE DIN.NUNOTA = @FIELD_NUNOTA AND CAB.AD_BONIFICADO = 'S' AND VLRNOTA = 0
			UPDATE sankhya.TGFCAB SET VLRICMSFCP = 0, VLRICMSDIFALDEST=0, VLRICMSDIFALREM=0 WHERE NUNOTA = @FIELD_NUNOTA AND AD_BONIFICADO = 'S' AND VLRNOTA = 0;

			SET @I = @I + 1
       END
	   SET @P_MENSAGEM = 'Valores da nota processados com sucesso. Favor gerar lote. Caso persista com problema na aprovação, contate a TI.';
END
