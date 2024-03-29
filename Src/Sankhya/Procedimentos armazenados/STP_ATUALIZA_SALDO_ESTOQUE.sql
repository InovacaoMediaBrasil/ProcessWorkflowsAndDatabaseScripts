USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_ATUALIZA_SALDO_ESTOQUE]    Script Date: 15/03/2017 16:44:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_ATUALIZA_SALDO_ESTOQUE] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.   
) AS
DECLARE
	   @CODPROD INT,
	   @ESTOQUE DECIMAL(10,2),
	   @RESERVADO DECIMAL(10,2)	   
BEGIN
	/* 
		Trocar para efetuar o controle de acesso pelo Sankhya (na aba Ações, marcar "Controle de acesso"
		Dessa forma não é precisso acessar a procedure toda vez que for alterar os usuários, pode fazer pela tela de acessos mesmo...
	*/
	/* OBTEM OS DADOS DE CODIGO E QUANTIDADE DA TELA DO SANKHYA */
	SET @CODPROD = sankhya.ACT_INT_FIELD(@P_IDSESSAO,@P_QTDLINHAS,'CODPROD');
	SET @ESTOQUE = sankhya.ACT_DEC_PARAM(@P_IDSESSAO, 'ESTOQUE');

	/* OBTEM O RESERVADO DO PRODUTO ATRAVÉS DE FUNÇÃO*/
	SELECT @RESERVADO = sankhya.FN_CALCULA_RESERVADO(@CODPROD);

	/* ATUALIZA O ESTOQUE E O RESERVADO DO PRODUTO*/
	update sankhya.TGFEST SET ESTOQUE = @ESTOQUE, RESERVADO = @RESERVADO WHERE CODPROD = @CODPROD;
				
	/* INSERE NA TABELA DE HISTÓRICO DE ALTERAÇÕES */
	INSERT INTO AD_ESTHIST (CODPROD, DATACONT, ESTOQUE, RESERVADO, CODUSU, CODPARC)
	VALUES (@CODPROD,getdate(), @ESTOQUE, @RESERVADO, @P_CODUSU, (SELECT ISNULL(codprod,0) FROM TSIUSU WHERE CODUSU = @P_CODUSU));

	/* ALTERA NA MULTILOJA PARA ATUALIZAR O ESTOQUE NA VTEX */
	UPDATE AD_MULTILOJA SET DTMODIF = GETDATE(), ALTESTOQUE = 'S' WHERE CODPROD = @CODPROD;


	/* AVISA O USUÁRIO QUE O PROCEDIMENTO DEU CERTO */
	SET @P_MENSAGEM = 'Saldo atualizado para o produto ' + cast(@codprod as varchar(6));
END
